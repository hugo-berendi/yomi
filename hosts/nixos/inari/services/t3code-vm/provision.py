import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import urllib.request
from pathlib import Path


def _atomic_link(source: Path, destination: Path) -> bool:
    try:
        os.link(source, destination)
    except FileExistsError:
        return False
    source.unlink()
    return True


def download_image(url: str, sha256: str, destination: Path) -> bool:
    if destination.exists():
        return False
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as handle:
        temporary = Path(handle.name)
    try:
        urllib.request.urlretrieve(url, temporary)
        digest = hashlib.sha256(temporary.read_bytes()).hexdigest()
        if digest != sha256:
            raise ValueError(
                f"image checksum mismatch: expected {sha256}, got {digest}"
            )
        temporary.chmod(0o600)
        return _atomic_link(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def ensure_disk(image: Path, disk: Path, size: str, qemu_img: str) -> bool:
    if disk.exists():
        return False
    with tempfile.NamedTemporaryFile(dir=disk.parent, delete=False) as handle:
        temporary = Path(handle.name)
    try:
        shutil.copyfile(image, temporary)
        subprocess.run([qemu_img, "resize", str(temporary), size], check=True)
        temporary.chmod(0o600)
        return _atomic_link(temporary, disk)
    finally:
        temporary.unlink(missing_ok=True)


def render_seed(
    user_data: Path,
    network_config: Path,
    metadata: Path,
    management_key: Path,
    seed: Path,
    cloud_localds: str,
    guest_host_key: Path | None = None,
    guest_host_public_key: Path | None = None,
) -> bool:
    key = management_key.read_text(encoding="utf-8").strip()
    if not key:
        raise ValueError(f"management key is empty: {management_key}")
    inputs = [user_data, network_config, metadata, management_key]
    inputs += [
        path for path in [guest_host_key, guest_host_public_key] if path is not None
    ]
    fingerprint = hashlib.sha256(
        b"".join(hashlib.sha256(path.read_bytes()).digest() for path in inputs)
    ).hexdigest()
    marker = seed.with_suffix(".inputs-sha256")
    if seed.exists():
        if not marker.exists() or marker.read_text().strip() != fingerprint:
            raise ValueError(
                "cloud-init inputs changed: existing guest preserved; migrate/reprovision explicitly"
            )
        return False
    with tempfile.TemporaryDirectory(dir=seed.parent) as directory:
        root = Path(directory)
        rendered = root / "user-data"
        content = user_data.read_text(encoding="utf-8").replace(
            "__MANAGEMENT_PUBLIC_KEY__", key
        )
        if guest_host_key is not None:
            data = json.loads(content.removeprefix("#cloud-config\n"))
            data["ssh_keys"] = {
                "ed25519_private": guest_host_key.read_text(),
                "ed25519_public": guest_host_public_key.read_text().strip(),
            }
            content = "#cloud-config\n" + json.dumps(data)
        rendered.write_text(content, encoding="utf-8")
        temporary = root / "seed.iso"
        subprocess.run(
            [
                cloud_localds,
                "--disk-format=raw",
                str(temporary),
                str(rendered),
                str(metadata),
                f"--network-config={network_config}",
            ],
            check=True,
        )
        temporary.chmod(0o600)
        # Cloud-init first-boot configuration is immutable. Never pretend that
        # replacing a seed updates an already initialized guest or erase its auth.
        marker.write_text(fingerprint + "\n")
        marker.chmod(0o600)
        return _atomic_link(temporary, seed)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image-url", required=True)
    parser.add_argument("--image-sha256", required=True)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--disk", type=Path, required=True)
    parser.add_argument("--disk-size", required=True)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--cloud-localds", required=True)
    parser.add_argument("--qemu-img", required=True)
    parser.add_argument("--user-data", type=Path, required=True)
    parser.add_argument("--network-config", type=Path, required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--management-key", type=Path, required=True)
    parser.add_argument("--guest-host-key", type=Path)
    parser.add_argument("--guest-host-public-key", type=Path)
    args = parser.parse_args()
    args.image.parent.mkdir(parents=True, exist_ok=True)
    args.disk.parent.mkdir(parents=True, exist_ok=True)
    args.seed.parent.mkdir(parents=True, exist_ok=True)
    download_image(args.image_url, args.image_sha256, args.image)
    ensure_disk(args.image, args.disk, args.disk_size, args.qemu_img)
    render_seed(
        args.user_data,
        args.network_config,
        args.metadata,
        args.management_key,
        args.seed,
        args.cloud_localds,
        args.guest_host_key,
        args.guest_host_public_key,
    )


if __name__ == "__main__":
    main()
