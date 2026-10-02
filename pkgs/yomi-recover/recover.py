"""Offline recovery. Never infer permission to format from a previous run."""

import argparse
import contextlib
import curses
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile


FORMAT = 1
MIB = 1024 * 1024
CHUNK = 1024 * MIB
KEY = "/kagutsuchi/age/yomi-recovery.txt"
ROOT = "zroot/recovered"


class RecoveryError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise RecoveryError(message)


def run(*args, capture=False, **kwargs):
    if not capture:
        print("$", shlex.join(map(str, args)), flush=True)
    kwargs.setdefault("stdout", subprocess.PIPE if capture else None)
    return subprocess.run(
        list(map(str, args)),
        check=True,
        **kwargs,
    ).stdout


def output(*args):
    return run(*args, capture=True, text=True).strip()


def atomic_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + ".partial")
    with temporary.open("w") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)
    fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def digest(path):
    with Path(path).open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def records(nodes):
    for node in nodes:
        yield node
        yield from records(node.get("children", []))


def inventory():
    return json.loads(
        output(
            "lsblk",
            "--json",
            "--bytes",
            "--paths",
            "--output",
            "NAME,TYPE,SIZE,MODEL,SERIAL,WWN,LOG-SEC,MOUNTPOINTS,PKNAME,FSTYPE,UUID",
        )
    )["blockdevices"]


def disk_info(device):
    device = str(Path(device).resolve(strict=True))
    require(stat.S_ISBLK(os.stat(device).st_mode), "Select a block device, not a file.")
    matches = [n for n in records(inventory()) if n["name"] == device]
    require(len(matches) == 1, f"Cannot identify {device} unambiguously.")
    info = matches[0]
    require(info["type"] in ("disk", "loop"), "Select a whole disk.")
    return info


def descendants(info):
    return {n["name"] for n in records([info])}


def pool_devices(pool=None):
    command = ["zpool", "status", "-LP"] + ([pool] if pool else [])
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    return {
        str(Path(p).resolve()) for p in re.findall(r"^\s+(/\S+)\s", result.stdout, re.M)
    }


def backing_devices(path):
    # ZFS does not appear as a parent of its mounts in lsblk.
    source = output("findmnt", "--noheadings", "--output", "SOURCE", "--target", path)
    if source.startswith("/dev/"):
        return {str(Path(source.split("[")[0]).resolve())}
    if source.split("/")[0] in output("zpool", "list", "-H", "-o", "name").splitlines():
        return pool_devices(source.split("/")[0])
    require(
        source in ("tmpfs", "ramfs") or ":" in source or source.startswith("//"),
        f"Cannot establish backing disks for {path}: {source}",
    )
    return set()


def idle_disk(info, bundle=None):
    require(
        not any(
            n.get("mountpoints") and any(n["mountpoints"]) for n in records([info])
        ),
        "This disk has mounted filesystems or active swap. Unmount it first.",
    )
    require(
        not descendants(info) & pool_devices(),
        "This disk belongs to an imported ZFS pool. Export it first.",
    )
    if bundle:
        require(
            not descendants(info) & backing_devices(bundle),
            "The backup is on the selected disk.",
        )
    return info


def fingerprint(info):
    value = {k: info.get(k) for k in ("size", "serial", "wwn", "log-sec")}
    if not value["serial"] and not value["wwn"]:
        value["name"] = info["name"]
    return value


def confirmation(info, action, supplied=None):
    token = info.get("serial") or info.get("wwn") or Path(info["name"]).name
    print(
        f"\n{action}\nDisk: {info['name']}  {info.get('model')}  {info['size']} bytes\nIdentity: {token}"
    )
    entered = supplied if supplied is not None else input(f"Type {token} to continue: ")
    require(entered.strip() == str(token).strip(), "Disk confirmation does not match.")


@contextlib.contextmanager
def lock(bundle):
    with (Path(bundle) / ".lock").open("a") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RecoveryError(
                "Another recovery operation is using this bundle."
            ) from error
        yield


@contextlib.contextmanager
def disk_lock(device):
    # Bundles have separate locks, but two bundles must not write one disk.
    number = os.stat(Path(device).resolve()).st_rdev
    with Path(f"/run/yomi-recover-disk-{number}.lock").open("a") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RecoveryError(
                "Another recovery operation is using this disk."
            ) from error
        yield


def recipient(identity):
    require(
        Path(identity).is_file(),
        f"Recovery identity missing: {identity}. Open kagutsuchi first.",
    )
    return output("age-keygen", "-y", identity)


def encrypt_stream(reader, path, public_key, limit=None):
    """No plaintext temporary files; the manifest records both hashes and length."""
    path = Path(path)
    partial = path.with_suffix(path.suffix + ".partial")
    sha = hashlib.sha256()
    length = 0
    processes = []
    try:
        with partial.open("wb") as destination:
            age = subprocess.Popen(
                ["age", "-r", public_key], stdin=subprocess.PIPE, stdout=destination
            )
            processes.append(age)
            compressor = subprocess.Popen(
                ["zstd", "-q", "-T1", "-1"], stdin=subprocess.PIPE, stdout=age.stdin
            )
            processes.append(compressor)
            age.stdin.close()
            with compressor.stdin:
                while limit is None or length < limit:
                    block = reader.read(
                        min(4 * MIB, limit - length) if limit is not None else 4 * MIB
                    )
                    if not block:
                        break
                    compressor.stdin.write(block)
                    sha.update(block)
                    length += len(block)
            require(
                limit is None or length == limit,
                "Source ended before the expected byte count.",
            )
            require(compressor.wait() == 0 and age.wait() == 0, "Encryption failed.")
            destination.flush()
            os.fsync(destination.fileno())
        os.replace(partial, path)
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
            process.wait()
    return {
        "file": path.name,
        "bytes": length,
        "sha256": sha.hexdigest(),
        "encrypted_sha256": digest(path),
    }


@contextlib.contextmanager
def decrypt_stream(path, identity):
    processes = []
    try:
        age = subprocess.Popen(
            ["age", "-d", "-i", str(identity), str(path)], stdout=subprocess.PIPE
        )
        processes.append(age)
        decompressor = subprocess.Popen(
            ["zstd", "-q", "-d"], stdin=age.stdout, stdout=subprocess.PIPE
        )
        processes.append(decompressor)
        age.stdout.close()
        with decompressor.stdout as reader:
            yield reader
        require(
            decompressor.wait() == 0 and age.wait() == 0,
            "Decryption failed or the archive is incomplete.",
        )
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
            process.wait()


def artifact_path(bundle, entry):
    name = entry["file"]
    require(
        isinstance(name, str) and Path(name).name == name and name not in (".", ".."),
        "Invalid artifact filename.",
    )
    path = Path(bundle) / name
    require(not path.is_symlink(), "Backup artifacts must not be symlinks.")
    return path


def check_artifact(bundle, entry, identity, sink=None):
    path = artifact_path(bundle, entry)
    require(
        digest(path) == entry["encrypted_sha256"],
        f"Encrypted checksum mismatch: {path.name}",
    )
    sha = hashlib.sha256()
    size = 0
    with decrypt_stream(path, identity) as reader:
        while block := reader.read(4 * MIB):
            size += len(block)
            require(size <= entry["bytes"], f"Oversized artifact: {path.name}")
            sha.update(block)
            if sink is not None:
                sink.write(block)
    require(
        size == entry["bytes"] and sha.hexdigest() == entry["sha256"],
        f"Decoded checksum mismatch: {path.name}",
    )


def seal(bundle, manifest, public_key):
    import io

    encrypt_stream(
        io.BytesIO(json.dumps(manifest).encode()),
        Path(bundle) / "manifest.json.age",
        public_key,
    )


def load_manifest(bundle, identity):
    with decrypt_stream(Path(bundle) / "manifest.json.age", identity) as handle:
        data = handle.read(8 * MIB + 1)
    require(len(data) <= 8 * MIB, "Manifest is too large.")
    value = json.loads(data)
    require(value["format"] == FORMAT, "Unsupported backup format.")
    require(value.get("complete"), "The final backup has not completed.")
    offset = 0
    for entry in value["image"]:
        require(
            entry["offset"] == offset and 0 < entry["bytes"] <= CHUNK,
            "Invalid image chunk layout.",
        )
        offset += entry["bytes"]
    require(offset == value["source"]["size"], "Image does not cover the entire SSD.")
    return value


def all_artifacts(manifest):
    return manifest["image"] + list(manifest["artifacts"].values())


def verify_bundle(bundle, identity):
    manifest = load_manifest(bundle, identity)
    for index, entry in enumerate(all_artifacts(manifest), 1):
        print(f"Verifying {index}: {entry['file']}", flush=True)
        check_artifact(bundle, entry, identity)
    print("PASS: every artifact decrypted and matched its byte count and SHA-256.")
    return manifest


def command_artifact(bundle, name, public_key, *args):
    process = subprocess.Popen(list(map(str, args)), stdout=subprocess.PIPE)
    try:
        with process.stdout as reader:
            entry = encrypt_stream(reader, Path(bundle) / name, public_key)
        require(process.wait() == 0, f"Archive producer failed: {args[0]}")
        return entry
    finally:
        if process.poll() is None:
            process.terminate()
        process.wait()


def check_recovery_key(identity, encrypted_key, root):
    with tempfile.TemporaryDirectory(prefix="yomi-key-check-", dir="/run") as directory:
        key = Path(directory) / "disk.key"
        with key.open("wb") as handle:
            run("age", "-d", "-i", identity, encrypted_key, stdout=handle)
        require(key.stat().st_size > 0, "The recovered disk key is empty.")
        # -n validates the supplied key without changing the pool's loaded key.
        run("zfs", "load-key", "-n", "-L", "file://" + str(key), root)


def prepare(args):
    repo = Path(args.repo).resolve()
    bundle = Path(args.bundle).resolve()
    require((repo / "flake.lock").is_file(), "Select the Yomi checkout.")
    bundle.mkdir(parents=True, exist_ok=True)
    require(not bundle.is_relative_to(repo), "Keep the bundle outside the checkout.")
    public_key = recipient(args.identity)
    root = output("findmnt", "-n", "-o", "SOURCE", "--mountpoint", "/")
    require(root in ("zroot", ROOT), "Prepare recovery on the running Inari system.")
    check_recovery_key(args.identity, "/boot/zroot-recovery-key.age", root)
    with lock(bundle):
        require(
            not (bundle / "manifest.json.age").exists(),
            "A completed bundle already exists. Use a new directory.",
        )
        archive = json.loads(
            output(
                "nix",
                "flake",
                "archive",
                "--json",
                "--no-write-lock-file",
                "--accept-flake-config",
                str(repo),
            )
        )
        paths = set()

        def collect(node):
            paths.add(node["path"])
            for child in node.get("inputs", {}).values():
                collect(child)

        collect(archive)
        manifest = {
            "format": FORMAT,
            "complete": False,
            "image": [],
            "artifacts": {},
            "recipient": public_key,
            "created": datetime.datetime.now(datetime.UTC).isoformat(),
            "revision": output("git", "-C", repo, "rev-parse", "HEAD"),
        }
        manifest["artifacts"]["inputs"] = command_artifact(
            bundle,
            "inputs.nar.zst.age",
            public_key,
            "nix-store",
            "--export",
            *sorted(paths),
        )
        manifest["artifacts"]["config"] = command_artifact(
            bundle,
            "config.tar.zst.age",
            public_key,
            "tar",
            "--exclude=.git",
            "--exclude=result",
            "--exclude=result-*",
            "-C",
            repo,
            "-cf",
            "-",
            ".",
        )
        recovery = [
            "boot",
            "persist/state/etc/ssh",
            "persist/state/etc/secrets/initrd",
            "run/secrets/backup_password",
            "run/secrets/rendered/restic-b2.env",
            "run/secrets/rendered/restic-b2-repository",
        ]
        for name in recovery:
            require((Path("/") / name).exists(), f"Recovery material missing: /{name}")
        manifest["artifacts"]["recovery"] = command_artifact(
            bundle,
            "recovery.tar.zst.age",
            public_key,
            "tar",
            "-h",
            "-C",
            "/",
            "-cf",
            "-",
            *recovery,
        )
        for entry in manifest["artifacts"].values():
            check_artifact(bundle, entry, args.identity)
        atomic_json(bundle / "work.json", manifest)
        print(
            "Prepared and decrypted the recovery material. Shut down cleanly and take the final backup from the ISO."
        )


@contextlib.contextmanager
def source_pool(info, pool):
    require(re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_-]*", pool), "Invalid pool name.")
    require(
        pool not in output("zpool", "list", "-H", "-o", "name").splitlines(),
        "Source pool already imported.",
    )
    with tempfile.TemporaryDirectory(prefix="yomi-source-", dir="/run") as directory:
        search = Path(directory) / "devices"
        search.mkdir()
        for index, name in enumerate(descendants(info)):
            (search / str(index)).symlink_to(name)
        run(
            "zpool",
            "import",
            "-N",
            "-f",
            "-d",
            search,
            "-o",
            "cachefile=none",
            "-R",
            directory,
            pool,
        )
        try:
            require(
                pool_devices(pool) <= descendants(info),
                "Imported pool includes an unexpected disk.",
            )
            yield
        finally:
            run("zpool", "export", pool)


def backup(args):
    bundle = Path(args.bundle).resolve()
    require((bundle / "work.json").is_file(), "Run prepare on the old server first.")
    public_key = recipient(args.identity)
    info = idle_disk(disk_info(args.source), bundle)
    confirmation(
        info,
        "Read the ENTIRE offline SSD into this encrypted backup bundle",
        args.confirm,
    )
    with lock(bundle):
        manifest = json.loads((bundle / "work.json").read_text())
        require(
            manifest["recipient"] == public_key,
            "Use the same recovery identity as prepare.",
        )
        require(
            not manifest.get("complete"),
            "This backup already completed. Use a new bundle for a new capture.",
        )
        if "source" in manifest:
            require(
                manifest["source"] == fingerprint(info),
                "The source disk identity or capacity changed.",
            )
        else:
            manifest.update(
                source=fingerprint(info),
                pool=args.pool,
                snapshot="yomi-migration-"
                + datetime.datetime.now(datetime.UTC).strftime("%Y%m%dT%H%M%SZ"),
            )
            atomic_json(bundle / "work.json", manifest)
        require(args.pool == manifest["pool"], "The source pool changed.")
        # Re-reading completed chunks detects writes to the SSD between attempts.
        with open(info["name"], "rb", buffering=0) as source:
            for entry in manifest["image"]:
                if manifest.get("image_captured"):
                    check_artifact(bundle, entry, args.identity)
                    continue
                source.seek(entry["offset"])
                sha = hashlib.sha256()
                remaining = entry["bytes"]
                while remaining:
                    block = source.read(min(4 * MIB, remaining))
                    require(bool(block), "Source read failed.")
                    sha.update(block)
                    remaining -= len(block)
                require(
                    sha.hexdigest() == entry["sha256"],
                    "Source changed since the interrupted backup. Start a new bundle.",
                )
                check_artifact(bundle, entry, args.identity)
            offset = sum(e["bytes"] for e in manifest["image"])
            source.seek(offset)
            free_needed = info["size"] - offset + 2 * CHUNK
            require(
                shutil.disk_usage(bundle).free >= free_needed,
                "Not enough free space for the remaining image.",
            )
            while offset < info["size"]:
                print(
                    f"Imaging {offset / info['size']:.1%} ({offset} / {info['size']} bytes)",
                    flush=True,
                )
                entry = encrypt_stream(
                    source,
                    bundle / f"ssd-{offset // CHUNK:06d}.zst.age",
                    public_key,
                    min(CHUNK, info["size"] - offset),
                )
                entry["offset"] = offset
                manifest["image"].append(entry)
                atomic_json(bundle / "work.json", manifest)
                offset += entry["bytes"]
        # Do not import or snapshot the source until the complete image exists.
        # If replication is interrupted, retry it without re-imaging changed ZFS metadata.
        manifest["image_captured"] = True
        atomic_json(bundle / "work.json", manifest)
        with source_pool(info, args.pool):
            snap = f"{args.pool}@{manifest['snapshot']}"
            if subprocess.run(
                ["zfs", "list", "-H", "-t", "snapshot", snap],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode:
                run("zfs", "snapshot", "-r", snap)
            require(
                subprocess.run(
                    ["zfs", "list", "-H", "-t", "snapshot", f"{args.pool}@blank"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                ).returncode
                == 0,
                "Source lacks the @blank snapshot required by impermanence.",
            )
            estimated = run(
                "zfs",
                "send",
                "-nP",
                "-Rw",
                snap,
                capture=True,
                text=True,
                stderr=subprocess.STDOUT,
            )
            print(estimated)
            estimates = re.findall(r"^size\s+(\d+)$", estimated, re.M)
            if estimates:
                require(
                    shutil.disk_usage(bundle).free >= int(estimates[-1]) + CHUNK,
                    "Not enough space for the ZFS replication stream.",
                )
            manifest["artifacts"]["zfs"] = command_artifact(
                bundle, "zroot.zfs.zst.age", public_key, "zfs", "send", "-Rw", snap
            )
        # The ESP is outside ZFS, so preserve it independently for Disko restores.
        esp = [n for n in records([info]) if n.get("fstype") == "vfat"]
        require(len(esp) == 1, "Expected exactly one EFI filesystem on the source SSD.")
        with tempfile.TemporaryDirectory(prefix="yomi-esp-", dir="/run") as directory:
            run("mount", "-o", "ro", esp[0]["name"], directory)
            try:
                manifest["artifacts"]["boot"] = command_artifact(
                    bundle,
                    "boot.tar.zst.age",
                    public_key,
                    "tar",
                    "-C",
                    directory,
                    "-cf",
                    "-",
                    ".",
                )
            finally:
                run("umount", directory)
        # Publish the authenticated manifest only after every artifact verifies.
        manifest["complete"] = True
        seal(bundle, manifest, public_key)
        verify_bundle(bundle, args.identity)
        atomic_json(bundle / "work.json", manifest)
        checksums = {
            entry["file"]: entry["encrypted_sha256"]
            for entry in all_artifacts(manifest)
        }
        checksums["manifest.json.age"] = digest(bundle / "manifest.json.age")
        atomic_json(bundle / "checksums.json", checksums)
        (bundle / "Verify-Copy.ps1").write_text(
            "$ErrorActionPreference = 'Stop'\n"
            "$checks = Get-Content (Join-Path $PSScriptRoot 'checksums.json') -Raw | ConvertFrom-Json\n"
            "foreach ($p in $checks.PSObject.Properties) {\n"
            "  if ([IO.Path]::GetFileName($p.Name) -ne $p.Name) { throw 'Invalid filename' }\n"
            "  $actual = (Get-FileHash (Join-Path $PSScriptRoot $p.Name) -Algorithm SHA256).Hash\n"
            "  if ($actual.ToLower() -ne $p.Value) { throw ('Checksum mismatch: ' + $p.Name) }\n"
            "  Write-Host ('OK ' + $p.Name)\n"
            "}\nWrite-Host 'Transfer checks passed. Test decryption from the recovery ISO as well.'\n"
        )
        print(
            "Backup complete. Copy this directory to the Windows PC and verify that copy before returning the Beelink."
        )


def restore_image(args):
    bundle = Path(args.bundle).resolve()
    with lock(bundle):
        manifest = verify_bundle(bundle, args.identity)
        info = idle_disk(disk_info(args.target), bundle)
        require(
            info["size"] >= manifest["source"]["size"],
            "Replacement SSD is smaller than the original in bytes. Use the Disko/ZFS route.",
        )
        require(
            info["log-sec"] == manifest["source"]["log-sec"],
            "Logical sector sizes differ. Use the Disko/ZFS route.",
        )
        confirmation(
            info,
            "ERASE the selected disk and restore every byte of the original SSD",
            args.confirm,
        )
        # Keep journal outside the target. Always validate already-written chunks.
        state_path = bundle / "image-restore.json"
        state = {
            "target": fingerprint(info),
            "manifest": digest(bundle / "manifest.json.age"),
            "chunks": [],
        }
        if state_path.exists():
            previous = json.loads(state_path.read_text())
            require(
                previous["target"] == state["target"]
                and previous["manifest"] == state["manifest"],
                "Restore journal belongs to a different disk or backup.",
            )
            state = previous
        with open(info["name"], "r+b", buffering=0) as target:
            for entry in manifest["image"]:
                target.seek(entry["offset"])
                if entry["file"] in state["chunks"]:
                    sha = hashlib.sha256()
                    remaining = entry["bytes"]
                    while remaining:
                        block = target.read(min(4 * MIB, remaining))
                        require(bool(block), "Target read failed.")
                        sha.update(block)
                        remaining -= len(block)
                    if sha.hexdigest() == entry["sha256"]:
                        continue
                target.seek(entry["offset"])
                print(f"Restoring {entry['file']}", flush=True)
                check_artifact(bundle, entry, args.identity, target)
                os.fsync(target.fileno())
                target.seek(entry["offset"])
                sha = hashlib.sha256()
                remaining = entry["bytes"]
                while remaining:
                    block = target.read(min(4 * MIB, remaining))
                    require(bool(block), "Target read failed.")
                    sha.update(block)
                    remaining -= len(block)
                require(
                    sha.hexdigest() == entry["sha256"], "Read-back verification failed."
                )
                if entry["file"] not in state["chunks"]:
                    state["chunks"].append(entry["file"])
                atomic_json(state_path, state)
        run("blockdev", "--rereadpt", info["name"])
        print(
            "Exact SSD image restored and read back. Use 'Adapt existing installation' before booting on new hardware."
        )


def unpack_artifact(bundle, entry, identity, directory):
    import tarfile

    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    # Python's data filter rejects absolute paths, escaping links and devices.
    with decrypt_stream(artifact_path(bundle, entry), identity) as reader:
        with tarfile.open(fileobj=reader, mode="r|") as archive:
            archive.extractall(directory, filter="data")


def checkout(args, manifest, directory):
    repo = Path(directory) / "config"
    unpack_artifact(args.bundle, manifest["artifacts"]["config"], args.identity, repo)
    with decrypt_stream(
        artifact_path(args.bundle, manifest["artifacts"]["inputs"]), args.identity
    ) as reader:
        run("nix-store", "--import", stdin=reader)
    run("git", "-C", repo, "init", "-q")
    run("git", "-C", repo, "add", "--all")
    run(
        "nix",
        "flake",
        "archive",
        "--offline",
        "--no-write-lock-file",
        "--accept-flake-config",
        repo,
    )
    return repo


def stable_device(info):
    for path in sorted(Path("/dev/disk/by-id").glob("*")):
        if path.resolve() == Path(info["name"]) and "-part" not in path.name:
            return str(path)
    return info["name"]


def esp_device(info):
    device = stable_device(info)
    if device.startswith("/dev/disk/by-id/"):
        return device + "-part1"
    return device + ("p1" if device[-1].isdigit() else "1")


def zfs_partition(info):
    device = info["name"]
    return device + ("p2" if device[-1].isdigit() else "2")


def disko_scripts(directory, info):
    device = info["name"]
    require(re.fullmatch(r"/dev/[a-zA-Z0-9_/.-]+", device), "Unsupported disk path.")
    suffix = "p" if device[-1].isdigit() else ""
    replacements = {
        "/dev/yomi-recovery-disk": device,
        "/dev/yomi-recovery-esp": device + suffix + "1",
        "/dev/yomi-recovery-zfs": device + suffix + "2",
    }
    scripts = []
    for mode in ("DESTROY", "FORMAT"):
        compiled = list(Path(os.environ[f"YOMI_DISKO_{mode}"]).glob("bin/*"))
        require(len(compiled) == 1, "Missing prebuilt Disko script.")
        text = compiled[0].read_text()
        for placeholder, actual in replacements.items():
            text = text.replace(placeholder, actual)
        if mode == "FORMAT":
            text = scoped_disko(text, replacements["/dev/yomi-recovery-zfs"])
        path = Path(directory) / (mode.lower() + ".sh")
        path.write_text(text)
        path.chmod(0o700)
        scripts.append(path)
    return scripts


def scoped_disko(text, partition):
    # Disko otherwise searches all attached disks for an exported zroot, which
    # can import the original SSD instead of creating the replacement pool.
    require("zpool import " in text, "Compiled Disko pool import changed; inspect it.")
    return text.replace("zpool import ", f"zpool import -d {shlex.quote(partition)} ")


def recovery_mountpoint(path, empty=False):
    path = Path(path).resolve()
    require(
        path.is_relative_to("/mnt"), "Recovery mountpoints must be /mnt or below it."
    )
    if empty:
        mounts = json.loads(output("findmnt", "--json", "--output", "TARGET"))[
            "filesystems"
        ]
        require(
            not any(Path(m["target"]).is_relative_to(path) for m in records(mounts)),
            "Recovery mountpoint is already mounted. Inspect it before starting another restore.",
        )
    return path


def clear_stale_zfs_labels(info):
    # Disko's disk-deactivate helper destroys pools by label name. A stale label
    # on an idle disk must never make it destroy a retained pool on other disks.
    idle_disk(info)
    for node in records([info]):
        if node.get("fstype") == "zfs_member":
            run("zpool", "labelclear", "-f", node["name"])


def mount_root(pool, root, identity, boot, mountpoint):
    mountpoint = Path(mountpoint)
    mountpoint.mkdir(parents=True, exist_ok=True)
    # Decrypted disk keys live only on the ISO's tmpfs, never on raid5pool.
    if output("zfs", "get", "-H", "-o", "value", "keystatus", root) != "available":
        with tempfile.TemporaryDirectory(prefix="yomi-key-", dir="/run") as directory:
            keyfile = Path(directory) / "disk.key"
            with keyfile.open("wb") as handle:
                run(
                    "age",
                    "-d",
                    "-i",
                    identity,
                    Path(boot) / "zroot-recovery-key.age",
                    stdout=handle,
                )
            run("zfs", "load-key", "-L", f"file://{keyfile}", root)
    locations = {
        root: "/",
        root + "/root/local/nix": "/nix",
        root + "/root/local/cache": "/persist/local/cache",
        root + "/root/persist/data": "/persist/data",
        root + "/root/persist/state": "/persist/state",
    }
    for dataset, location in locations.items():
        target = mountpoint / location.lstrip("/")
        target.mkdir(parents=True, exist_ok=True)
        mounted = subprocess.run(
            ["findmnt", "-n", "-o", "SOURCE", "--mountpoint", target],
            capture_output=True,
            text=True,
        )
        if mounted.returncode == 0:
            require(
                mounted.stdout.strip() == dataset, f"Unexpected filesystem at {target}."
            )
        else:
            run("mount", "-t", "zfs", "-o", "zfsutil", dataset, target)
    (mountpoint / "boot").mkdir(exist_ok=True)


def overrides(repo, info, root, args):
    host = repo / "hosts/nixos/inari"
    require(
        (host / "default.nix").is_file(), "Recovery checkout does not contain inari."
    )
    require(
        args.lan and re.fullmatch(r"[a-zA-Z0-9_.:-]+", args.lan),
        "Select the new LAN interface.",
    )
    require(
        not args.wifi or re.fullmatch(r"[a-zA-Z0-9_.:-]+", args.wifi),
        "Invalid Wi-Fi interface.",
    )
    values = {
        "yomi.inari.rootDataset": root,
        "yomi.inari.beelinkWorkarounds": args.beelink,
        "yomi.inari.tpmUnlock": args.tpm,
        "yomi.inari.lanInterface": args.lan,
        "yomi.inari.wifiInterface": args.wifi or None,
        "disko.devices.disk.x.device": stable_device(info),
        'fileSystems."/boot".device': esp_device(info),
    }
    # JSON literals are valid Nix strings/bools/null; interface names are validated.
    text = (
        "{lib, ...}: {\n"
        + "".join(
            f"  {key} = lib.mkForce {json.dumps(value)};\n"
            for key, value in values.items()
        )
        + "}\n"
    )
    (host / "recovery-local.nix").write_text(text)
    run("git", "-C", repo, "add", "hosts/nixos/inari/recovery-local.nix")


def adapt_install(args, manifest, repo, info, root, mountpoint):
    mountpoint = Path(mountpoint)
    boot = mountpoint / "boot"
    require(
        (boot / "zroot-recovery-key.age").is_file(),
        "Missing independently encrypted ZFS recovery key.",
    )
    if args.tpm:
        require(
            Path("/dev/tpmrm0").exists(), "No TPM available. Choose manual unlocking."
        )
        with tempfile.TemporaryDirectory(prefix="yomi-tpm-", dir="/run") as directory:
            keyfile = Path(directory) / "disk.key"
            with keyfile.open("wb") as handle:
                run(
                    "age",
                    "-d",
                    "-i",
                    args.identity,
                    boot / "zroot-recovery-key.age",
                    stdout=handle,
                )
            partial = boot / "zroot-key.jwe.partial"
            with keyfile.open("rb") as source, partial.open("wb") as destination:
                run(
                    "clevis",
                    "encrypt",
                    "tpm2",
                    '{"pcr_bank":"sha256","pcr_ids":"7"}',
                    stdin=source,
                    stdout=destination,
                )
            os.replace(partial, boot / "zroot-key.jwe")
            with (boot / "zroot-key.jwe").open("rb") as encrypted:
                recovered = run("clevis", "decrypt", capture=True, stdin=encrypted)
            require(
                hashlib.sha256(recovered).hexdigest() == digest(keyfile),
                "New TPM enrollment did not decrypt to the recovered disk key.",
            )
    overrides(repo, info, root, args)
    generated = output(
        "nixos-generate-config",
        "--root",
        mountpoint,
        "--no-filesystems",
        "--show-hardware-config",
    )
    require(bool(generated), "Hardware generation produced nothing.")
    (repo / "hosts/nixos/inari/hardware/generated.nix").write_text(generated + "\n")
    run("git", "-C", repo, "add", "hosts/nixos/inari/hardware/generated.nix")
    run(
        "nix",
        "eval",
        "--raw",
        "--accept-flake-config",
        f"{repo}#nixosConfigurations.inari.config.system.build.toplevel.drvPath",
    )
    run(
        "nixos-install",
        "--root",
        mountpoint,
        "--flake",
        f"{repo}#inari",
        "--no-root-passwd",
        "--accept-flake-config",
    )
    config_path = mountpoint / "persist/state/etc/yomi"
    config_path.mkdir(parents=True, exist_ok=True)
    run("rsync", "-a", "--exclude=.git", str(repo) + "/", str(config_path) + "/")
    print(
        f"Installed the adapted configuration. Keep using {config_path} for future rebuilds; it includes recovery-local.nix."
    )


def restore_zfs(args):
    recovery_mountpoint(args.mountpoint, empty=True)
    bundle = Path(args.bundle).resolve()
    require(
        not bundle.is_relative_to(Path(args.mountpoint).resolve()),
        "Mount backup storage outside the target root mountpoint.",
    )
    with (
        lock(bundle),
        tempfile.TemporaryDirectory(prefix="yomi-restore-", dir="/run") as temporary,
    ):
        manifest = verify_bundle(bundle, args.identity)
        info = idle_disk(disk_info(args.target), bundle)
        require(
            "zfs" in manifest["artifacts"], "This bundle has no ZFS migration stream."
        )
        require(
            "zroot" not in output("zpool", "list", "-H", "-o", "name").splitlines(),
            "Export existing zroot before starting a new ZFS restore.",
        )
        repo = checkout(args, manifest, temporary) if not args.no_install else None
        if repo:
            overrides(repo, info, ROOT, args)
            run(
                "nix",
                "eval",
                "--raw",
                "--accept-flake-config",
                f"{repo}#nixosConfigurations.inari.config.system.build.toplevel.drvPath",
            )
        journal = bundle / "zfs-restore.json"
        require(
            not journal.exists(),
            "A ZFS restore already started. Use 'Continue installation' to inspect it. Never reformat automatically.",
        )
        state = {
            "target": fingerprint(info),
            "manifest": digest(bundle / "manifest.json.age"),
            "stage": "partitioning",
        }
        # A plain parent pool permits receiving the original encrypted root as
        # a child. Receiving onto Disko's already-encrypted zroot cannot work.
        scripts = disko_scripts(temporary, info)
        confirmation(
            info,
            "ERASE the target, partition with Disko, restore ZFS, and install NixOS",
            args.confirm,
        )
        idle_disk(disk_info(args.target), bundle)
        atomic_json(journal, state)
        clear_stale_zfs_labels(disk_info(args.target))
        for script in scripts:
            # The wizard already required the exact disk identity.
            run(script, "--yes-wipe-all-disks")
        require(
            pool_devices("zroot") == {zfs_partition(info)},
            "Disko imported a pool outside the selected target. Stop before receiving.",
        )
        state["stage"] = "receiving"
        atomic_json(journal, state)
        with decrypt_stream(
            artifact_path(bundle, manifest["artifacts"]["zfs"]), args.identity
        ) as reader:
            run("zfs", "receive", "-u", ROOT, stdin=reader)
        run("zfs", "set", "keylocation=prompt", ROOT)
        state["stage"] = "received"
        atomic_json(journal, state)
        run("zfs", "list", "-H", "-t", "snapshot", ROOT + "@blank")
        esp = [
            n for n in records([disk_info(args.target)]) if n.get("fstype") == "vfat"
        ]
        require(len(esp) == 1, "Cannot identify the target ESP.")
        with tempfile.TemporaryDirectory(prefix="yomi-boot-", dir="/run") as boot:
            unpack_artifact(bundle, manifest["artifacts"]["boot"], args.identity, boot)
            mount_root("zroot", ROOT, args.identity, boot, args.mountpoint)
        run("mount", esp[0]["name"], Path(args.mountpoint) / "boot")
        unpack_artifact(
            bundle,
            manifest["artifacts"]["boot"],
            args.identity,
            Path(args.mountpoint) / "boot",
        )
        if not args.no_install:
            adapt_install(args, manifest, repo, info, ROOT, args.mountpoint)
        state["stage"] = "restored" if args.no_install else "installed"
        atomic_json(journal, state)
        print(
            "ZFS restored. Filesystems are mounted for inspection. Reboot only after the installation checks pass."
        )


def continue_install(args):
    recovery_mountpoint(args.mountpoint)
    bundle = Path(args.bundle).resolve()
    require(
        not bundle.is_relative_to(Path(args.mountpoint).resolve()),
        "Mount backup storage outside the target root mountpoint.",
    )
    with (
        lock(bundle),
        tempfile.TemporaryDirectory(prefix="yomi-adapt-", dir="/run") as temporary,
    ):
        manifest = verify_bundle(bundle, args.identity)
        info = disk_info(args.target)
        journal = bundle / "zfs-restore.json"
        root = "zroot"
        if journal.exists():
            state = json.loads(journal.read_text())
            require(
                state["target"] == fingerprint(info)
                and state["manifest"] == digest(bundle / "manifest.json.age"),
                "Restore journal belongs to a different disk or bundle.",
            )
            require(
                state["stage"] in ("received", "restored", "installed"),
                "Partitioning or receive was interrupted. Inspect the target in the rescue shell; no automatic reformat is allowed.",
            )
            root = ROOT
        repo = checkout(args, manifest, temporary)
        # Only this target pool may already be imported. Protect every other disk.
        active = output("zpool", "list", "-H", "-o", "name").splitlines()
        if "zroot" not in active:
            idle_disk(info, bundle)
            with tempfile.TemporaryDirectory(
                prefix="yomi-import-", dir="/run"
            ) as search:
                for index, name in enumerate(descendants(info)):
                    (Path(search) / str(index)).symlink_to(name)
                run(
                    "zpool",
                    "import",
                    "-N",
                    "-f",
                    "-d",
                    search,
                    "-o",
                    "cachefile=none",
                    "-R",
                    args.mountpoint,
                    "zroot",
                )
        require(
            pool_devices("zroot") <= descendants(info),
            "Imported zroot is not the selected disk.",
        )
        confirmation(
            info,
            "Adapt this installation for the selected hardware and reinstall its bootloader",
            args.confirm,
        )
        esp = [n for n in records([info]) if n.get("fstype") == "vfat"]
        require(len(esp) == 1, "Cannot identify the target ESP.")
        mounted = subprocess.run(
            ["findmnt", "-n", "-o", "SOURCE", "--mountpoint", args.mountpoint],
            capture_output=True,
            text=True,
        )
        if mounted.returncode == 0:
            require(
                mounted.stdout.strip() == root,
                "The selected mountpoint contains a different root filesystem.",
            )
        target_mounts = [
            m for n in records([info]) for m in n.get("mountpoints") or [] if m
        ]
        require(
            all(m == str(Path(args.mountpoint) / "boot") for m in target_mounts),
            "The selected disk is mounted outside the recovery mountpoint.",
        )
        require(
            output("findmnt", "-n", "-o", "SOURCE", "--mountpoint", "/")
            not in (root, "zroot", ROOT),
            "Cannot adapt the currently running system. Boot the ISO.",
        )
        if not Path(args.mountpoint, "boot/zroot-recovery-key.age").is_file():
            with tempfile.TemporaryDirectory(prefix="yomi-boot-", dir="/run") as boot:
                run("mount", "-o", "ro", esp[0]["name"], boot)
                try:
                    mount_root("zroot", root, args.identity, boot, args.mountpoint)
                finally:
                    run("umount", boot)
            run("mount", esp[0]["name"], Path(args.mountpoint) / "boot")
        adapt_install(args, manifest, repo, info, root, args.mountpoint)
        if journal.exists():
            state["stage"] = "installed"
            atomic_json(journal, state)


def import_raid(args):
    require(
        args.pool == "raid5pool",
        "This action only imports raid5pool; it never creates a pool.",
    )
    if "raid5pool" in output("zpool", "list", "-H", "-o", "name").splitlines():
        readonly = output("zpool", "get", "-H", "-o", "value", "readonly", "raid5pool")
        if args.writable and readonly == "on":
            require(
                Path("/etc/yomi-recovery-iso").exists(),
                "Only reimport the HDD pool from the recovery ISO.",
            )
            run("zpool", "export", "raid5pool")
        else:
            run("zpool", "status", "raid5pool")
            return
    run(
        "zpool",
        "import",
        "-N",
        "-o",
        "readonly=off" if args.writable else "readonly=on",
        "-o",
        "cachefile=none",
        "raid5pool",
    )
    run("zfs", "mount", "raid5pool")
    if (
        subprocess.run(
            ["zfs", "list", "raid5pool/backups"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    ):
        run("zfs", "mount", "raid5pool/backups")
    print(
        "Imported retained HDD pool "
        + (
            "read-write for backup/restore journals."
            if args.writable
            else "read-only for inspection."
        )
    )


def fresh_install(args):
    """Install inari without restoring user data. Keys and inputs precede formatting."""
    require(
        Path(args.mountpoint) == Path("/mnt"),
        "Fresh installation currently requires /mnt.",
    )
    recovery_mountpoint(args.mountpoint, empty=True)
    info = idle_disk(disk_info(args.target))
    require(
        "zroot" not in output("zpool", "list", "-H", "-o", "name").splitlines(),
        "Export existing zroot before starting a fresh installation.",
    )
    source_repo = Path(args.repo).resolve()
    require(
        (source_repo / "flake.lock").is_file(),
        "Select a Yomi checkout, normally /iso/yomi on the ISO.",
    )
    keys = Path("/kagutsuchi/secrets/inari")
    for name in ("disk.key", "ssh_host_ed25519_key", "id_ed25519"):
        require((keys / name).is_file(), f"Missing install-time key: {keys / name}")
    public_key = recipient(args.identity)
    with tempfile.TemporaryDirectory(prefix="yomi-fresh-", dir="/run") as temporary:
        repo = Path(temporary) / "config"
        shutil.copytree(
            source_repo,
            repo,
            ignore=shutil.ignore_patterns(".git", "result", "result-*"),
        )
        run("git", "-C", repo, "init", "-q")
        run("git", "-C", repo, "add", "--all")
        overrides(repo, info, "zroot", args)
        run(
            "nix",
            "flake",
            "archive",
            "--no-write-lock-file",
            "--accept-flake-config",
            repo,
        )
        script = output(
            "nix",
            "build",
            "--no-link",
            "--print-out-paths",
            "--accept-flake-config",
            f"{repo}#nixosConfigurations.inari.config.system.build.diskoScript",
        )
        confirmation(
            info,
            "ERASE this disk and install a fresh inari, without restoring user data",
            args.confirm,
        )
        clear_stale_zfs_labels(disk_info(args.target))
        selected_script = Path(temporary) / "disko.sh"
        partition = zfs_partition(info)
        selected_script.write_text(scoped_disko(Path(script).read_text(), partition))
        selected_script.chmod(0o700)
        run(selected_script, "--yes-wipe-all-disks")
        require(
            pool_devices("zroot") == {str(Path(partition).resolve())},
            "Disko imported a pool outside the selected target.",
        )
        mountpoint = Path(args.mountpoint)
        user_keys = mountpoint / "persist/state/home/hugob/ssh/.ssh"
        host_keys = mountpoint / "persist/state/etc/ssh"
        initrd_keys = mountpoint / "persist/state/etc/secrets/initrd"
        for directory in (user_keys, host_keys, initrd_keys):
            directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        for key in keys.glob("id*"):
            shutil.copy2(key, user_keys / key.name)
        for key in keys.glob("ssh_host_*"):
            shutil.copy2(key, host_keys / key.name)
        run(
            "ssh-keygen",
            "-q",
            "-t",
            "rsa",
            "-b",
            "3072",
            "-N",
            "",
            "-f",
            initrd_keys / "ssh_host_rsa_key",
        )
        boot = mountpoint / "boot"
        with (boot / "zroot-recovery-key.age").open("wb") as destination:
            run("age", "-r", public_key, keys / "disk.key", stdout=destination)
        adapt_install(args, None, repo, info, "zroot", mountpoint)


def release_target(args):
    """Inspect exact mount sources before releasing a completed recovery target."""
    info = disk_info(args.target)
    mountpoint = recovery_mountpoint(args.mountpoint)
    require(
        pool_devices("zroot") <= descendants(info),
        "zroot does not belong to the selected disk.",
    )
    require(
        output("findmnt", "-n", "-o", "SOURCE", "--mountpoint", "/")
        not in ("zroot", ROOT),
        "Cannot release the live root pool.",
    )
    confirmation(
        info,
        "Unmount the recovered installation and export its root pool",
        args.confirm,
    )
    for relative in (
        "boot",
        "persist/state",
        "persist/data",
        "persist/local/cache",
        "nix",
        "",
    ):
        path = mountpoint / relative
        mounted = subprocess.run(
            ["findmnt", "-n", "-o", "SOURCE", "--mountpoint", path],
            capture_output=True,
            text=True,
        )
        if mounted.returncode == 0:
            source = mounted.stdout.strip()
            require(
                source.startswith("zroot")
                or str(Path(source).resolve()) in descendants(info),
                f"Unexpected mount at {path}: {source}",
            )
            run("umount", path)
    run("zpool", "export", "zroot")
    print("Target cleanly exported. You can reboot from the new SSD.")


def copy_bundle(args):
    source = Path(args.bundle).resolve()
    destination = Path(args.destination).resolve()
    require(
        source != destination and not destination.is_relative_to(source),
        "Select a separate destination for the second copy.",
    )
    with lock(source):
        manifest = verify_bundle(source, args.identity)
        destination.mkdir(parents=True, exist_ok=True)
        names = [entry["file"] for entry in all_artifacts(manifest)] + [
            "manifest.json.age",
            "checksums.json",
            "Verify-Copy.ps1",
        ]
        required = sum(
            (source / name).stat().st_size
            for name in names
            if not (destination / name).is_file()
        )
        require(
            shutil.disk_usage(destination).free >= required,
            "Not enough free space for the second copy.",
        )
        with tempfile.TemporaryDirectory(prefix="yomi-copy-", dir="/run") as temporary:
            files = Path(temporary) / "files"
            files.write_bytes(b"\0".join(name.encode() for name in names) + b"\0")
            run(
                "rsync",
                "-r",
                "--partial",
                "--checksum",
                "--info=progress2",
                "--from0",
                f"--files-from={files}",
                str(source) + "/",
                str(destination) + "/",
            )
        verify_bundle(destination, args.identity)
        print("Second copy transferred, decrypted, and verified.")


def mount_windows(args):
    import getpass

    require(
        re.fullmatch(r"[a-zA-Z0-9_.:-]+", args.server),
        "Invalid Windows server address.",
    )
    require(
        re.fullmatch(r"[a-zA-Z0-9_$ .-]+", args.share), "Invalid Windows share name."
    )
    require("\n" not in args.user, "Invalid Windows username.")
    mountpoint = Path(args.mountpoint).resolve()
    require(
        mountpoint.is_relative_to("/media") and mountpoint != Path("/media"),
        "Mount Windows shares below /media, separate from the installation at /mnt.",
    )
    require(
        subprocess.run(["mountpoint", "-q", mountpoint]).returncode != 0,
        "This mountpoint is already in use.",
    )
    password = getpass.getpass("Windows share password: ")
    require(
        "\n" not in password, "Newlines are not supported in a CIFS credential file."
    )
    with tempfile.TemporaryDirectory(prefix="yomi-cifs-", dir="/run") as temporary:
        credentials = Path(temporary) / "credentials"
        credentials.write_text(f"username={args.user}\npassword={password}\n")
        credentials.chmod(0o600)
        mountpoint.mkdir(parents=True, exist_ok=True)
        run(
            "mount",
            "-t",
            "cifs",
            f"//{args.server}/{args.share}",
            mountpoint,
            "-o",
            f"credentials={credentials},vers=3.0,nosuid,nodev,noexec",
        )
    print(
        f"Windows share mounted at {mountpoint}. Choose 'Copy verified bundle' or verify a bundle there."
    )


def parse(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action")
    commands.add_parser("disks", help="Show disks without changing anything")
    commands.add_parser("keys", help="Unlock the existing kagutsuchi key stick")
    raid = commands.add_parser(
        "import-raid", help="Import the retained HDD pool read-only"
    )
    raid.add_argument("--pool", default="raid5pool")
    raid.add_argument(
        "--writable",
        action="store_true",
        help="Mount retained storage for backup files and restore journals",
    )
    release = commands.add_parser(
        "release-target", help="Unmount a recovered installation and export its pool"
    )
    release.add_argument("--target", required=True)
    release.add_argument("--mountpoint", default="/mnt")
    release.add_argument("--confirm")
    windows = commands.add_parser(
        "mount-windows", help="Mount an existing Windows SMB share"
    )
    windows.add_argument("--server", required=True)
    windows.add_argument("--share", required=True)
    windows.add_argument("--user", required=True)
    windows.add_argument("--mountpoint", default="/media/windows-backup")
    for name in (
        "prepare",
        "backup",
        "verify",
        "restore-image",
        "restore-zfs",
        "continue-install",
        "fresh-install",
        "copy-bundle",
    ):
        sub = commands.add_parser(name)
        if name != "fresh-install":
            sub.add_argument("--bundle", required=True)
        sub.add_argument("--identity", default=KEY)
        if name == "copy-bundle":
            sub.add_argument("--destination", required=True)
        if name in ("prepare", "fresh-install"):
            sub.add_argument(
                "--repo",
                default="/iso/yomi" if name == "fresh-install" else os.getcwd(),
            )
        if name == "backup":
            sub.add_argument("--source", required=True)
            sub.add_argument("--pool", default="zroot")
        if name in (
            "restore-image",
            "restore-zfs",
            "continue-install",
            "fresh-install",
        ):
            sub.add_argument("--target", required=True)
        if name in (
            "backup",
            "restore-image",
            "restore-zfs",
            "continue-install",
            "fresh-install",
        ):
            sub.add_argument(
                "--confirm",
                help="Explicit disk serial/WWN for an unattended invocation",
            )
        if name in ("restore-zfs", "continue-install", "fresh-install"):
            sub.add_argument("--lan")
            sub.add_argument("--wifi", default="")
            sub.add_argument(
                "--tpm",
                action="store_true",
                help="Seal the recovered key to this PC's TPM",
            )
            sub.add_argument(
                "--beelink",
                action="store_true",
                help="Retain the old Beelink CPU workarounds",
            )
            sub.add_argument("--mountpoint", default="/mnt")
        if name == "restore-zfs":
            sub.add_argument(
                "--no-install",
                action="store_true",
                help="Restore and mount for inspection without installing",
            )
    return parser.parse_args(argv)


def unlock_keys():
    if subprocess.run(["mountpoint", "-q", "/kagutsuchi"]).returncode == 0:
        return
    run(
        "cryptsetup",
        "open",
        "/dev/disk/by-uuid/40ed3eaf-4232-4961-b87b-88b2f998ec10",
        "kagutsuchi",
    )
    Path("/kagutsuchi").mkdir(exist_ok=True)
    run("mount", "/dev/mapper/kagutsuchi", "/kagutsuchi")


def dispatch(args):
    require(
        os.geteuid() == 0 or args.action in ("disks", "verify"),
        "Run as root from the ISO, or use /run/wrappers/bin/sudo for prepare.",
    )
    os.umask(0o077)
    functions = {
        "prepare": prepare,
        "backup": backup,
        "verify": lambda a: verify_bundle(a.bundle, a.identity),
        "restore-image": restore_image,
        "restore-zfs": restore_zfs,
        "continue-install": continue_install,
        "import-raid": import_raid,
        "keys": lambda _: unlock_keys(),
        "disks": lambda _: print(json.dumps(inventory(), indent=2)),
        "fresh-install": fresh_install,
        "release-target": release_target,
        "copy-bundle": copy_bundle,
        "mount-windows": mount_windows,
    }
    device = getattr(args, "target", None) or getattr(args, "source", None)
    if device:
        with disk_lock(device):
            functions[args.action](args)
    else:
        functions[args.action](args)


def menu(screen, title, choices):
    selected = 0
    curses.curs_set(0)
    while True:
        screen.clear()
        height, width = screen.getmaxyx()
        require(
            height >= 16 and width >= 60,
            "Use a terminal at least 60 columns by 16 rows.",
        )
        screen.addnstr(1, 2, "YOMI / RECOVERY", width - 4, curses.A_BOLD)
        screen.addnstr(3, 2, title, width - 4)
        start = max(0, selected - (height - 8) + 1)
        for row, index in enumerate(
            range(start, min(len(choices), start + height - 8))
        ):
            label = choices[index]
            screen.addnstr(
                row + 5,
                2,
                ("> " if index == selected else "  ") + label,
                width - 4,
                curses.A_REVERSE if index == selected else curses.A_NORMAL,
            )
        screen.addnstr(height - 2, 2, "Arrow keys / Enter. Esc goes back.", width - 4)
        screen.refresh()
        key = screen.getch()
        if key in (curses.KEY_UP, ord("k")):
            selected = (selected - 1) % len(choices)
        elif key in (curses.KEY_DOWN, ord("j")):
            selected = (selected + 1) % len(choices)
        elif key in (10, 13):
            return selected
        elif key == 27:
            raise KeyboardInterrupt


def prompt(screen, title, default=""):
    screen.clear()
    height, width = screen.getmaxyx()
    screen.addnstr(2, 2, title, width - 4)
    screen.addnstr(
        4, 2, f"Default: {default}" if default else "Enter a value", width - 4
    )
    screen.addnstr(
        height - 2, 2, "Enter accepts. Empty input uses the default.", width - 4
    )
    curses.echo()
    curses.curs_set(1)
    try:
        value = screen.getstr(6, 2, max(1, width - 4)).decode().strip()
    finally:
        curses.noecho()
        curses.curs_set(0)
    return value or default


def wizard():
    choices = [
        ("backup", "Back up the entire offline SSD and its ZFS datasets"),
        ("restore-zfs", "Disko + ZFS restore + NixOS installation"),
        ("restore-image", "Restore the exact SSD image"),
        ("continue-install", "Adapt an existing installation / continue after restore"),
        ("prepare", "Prepare recovery material on the old server"),
        ("fresh-install", "Install a fresh inari with Disko"),
        ("verify", "Verify a backup, including decryption"),
        ("copy-bundle", "Copy a verified bundle to another device or Windows share"),
        ("mount-windows", "Connect to a Windows backup share"),
        ("keys", "Unlock kagutsuchi"),
        ("import-raid", "Import retained HDD pool read-only"),
        ("disks", "Inspect disks"),
        ("release-target", "Unmount and export the recovered SSD before reboot"),
        ("shell", "Open a rescue shell"),
        ("quit", "Exit"),
    ]
    bundle = "/raid5pool/backups/inari-migration"
    identity = KEY
    while True:

        def gather(screen):
            nonlocal bundle, identity
            action = choices[
                menu(screen, "Choose a workflow", [label for _, label in choices])
            ][0]
            if action == "import-raid":
                writable = menu(
                    screen,
                    "Retained HDD pool access",
                    ["Read-only inspection", "Read-write for backup and recovery"],
                )
                return action, ["--writable"] if writable else []
            if action == "mount-windows":
                return action, [
                    "--server",
                    prompt(screen, "Windows PC address or hostname"),
                    "--share",
                    prompt(screen, "Existing Windows share name"),
                    "--user",
                    prompt(screen, "Windows username"),
                    "--mountpoint",
                    "/media/windows-backup",
                ]
            if action in ("quit", "shell", "keys", "disks"):
                return action, []
            options = []
            if action not in ("fresh-install", "release-target"):
                bundle = prompt(screen, "Backup bundle directory", bundle)
                options += ["--bundle", bundle]
            if action != "release-target":
                identity = prompt(screen, "Independent age recovery identity", identity)
                options += ["--identity", identity]
            if action == "copy-bundle":
                options += [
                    "--destination",
                    prompt(
                        screen,
                        "Second copy directory",
                        "/media/windows-backup/inari-migration",
                    ),
                ]
            if action in ("prepare", "fresh-install"):
                options += [
                    "--repo",
                    prompt(
                        screen,
                        "Yomi checkout",
                        "/iso/yomi" if action == "fresh-install" else os.getcwd(),
                    ),
                ]
            if action in (
                "backup",
                "restore-zfs",
                "restore-image",
                "continue-install",
                "fresh-install",
                "release-target",
            ):
                disks = [n for n in inventory() if n["type"] == "disk"]
                require(bool(disks), "No whole disks found.")
                labels = [
                    f"{n['name']}  {n.get('model')}  {n['size'] / CHUNK:.1f} GiB  {n.get('serial')}"
                    for n in disks
                ]
                selected = disks[
                    menu(
                        screen,
                        "Source SSD"
                        if action == "backup"
                        else "Target SSD. Its contents may be overwritten.",
                        labels,
                    )
                ]
                options += [
                    "--source" if action == "backup" else "--target",
                    stable_device(selected),
                ]
            if action in ("restore-zfs", "continue-install", "fresh-install"):
                interfaces = [
                    p.name for p in Path("/sys/class/net").iterdir() if p.name != "lo"
                ]
                lan = interfaces[
                    menu(
                        screen,
                        "Select the LAN interface for the installed server",
                        interfaces,
                    )
                ]
                wifi_choices = ["No Wi-Fi access point"] + interfaces
                wifi_index = menu(screen, "Wi-Fi interface for hostapd", wifi_choices)
                options += [
                    "--lan",
                    lan,
                    "--wifi",
                    wifi_choices[wifi_index] if wifi_index else "",
                ]
                if (
                    menu(
                        screen,
                        "Disk unlocking on this PC",
                        ["Manual recovery key", "Automatic TPM unlocking"],
                    )
                    == 1
                ):
                    options += ["--tpm"]
                if (
                    menu(
                        screen,
                        "Hardware profile",
                        ["New PC", "Old Beelink rescue workarounds"],
                    )
                    == 1
                ):
                    options += ["--beelink"]
            return action, options

        try:
            action, options = curses.wrapper(gather)
            if action == "quit":
                return
            if action == "shell":
                run(os.environ.get("SHELL", "/bin/sh"))
            else:
                print(
                    "Workflow:",
                    shlex.join(["yomi-recover", action, *options]),
                    flush=True,
                )
                dispatch(parse([action, *options]))
        except KeyboardInterrupt:
            print("Cancelled. No later steps will run.")
        except (
            RecoveryError,
            OSError,
            subprocess.CalledProcessError,
            ValueError,
            KeyError,
        ) as error:
            print(f"Stopped: {error}", file=sys.stderr)
        input("Press Enter to return to recovery.")


def main():
    try:
        args = parse()
        if args.action is None:
            wizard()
        else:
            dispatch(args)
    except (
        RecoveryError,
        OSError,
        subprocess.CalledProcessError,
        ValueError,
        KeyError,
    ) as error:
        print(f"Stopped: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print(
            "Cancelled. Incomplete backups/restores are not successful.",
            file=sys.stderr,
        )
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
