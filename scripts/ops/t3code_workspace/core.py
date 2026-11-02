import contextlib
import fcntl
import hashlib
import io
import json
import os
import posixpath
import re
import subprocess
import tarfile
import tempfile
from pathlib import Path, PurePosixPath


class WorkspaceError(RuntimeError):
    pass


def _lock(path):
    handle = path.open("a+")
    fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
    return contextlib.closing(handle)


_SECRET = re.compile(
    r"(^|/)(\.env(?:\..*)?|secrets?[^/]*|.*\.(?:pem|key|p12|pfx|kdbx)|"
    r"id_(?:rsa|dsa|ecdsa|ed25519)|.*private.*key.*)$",
    re.IGNORECASE,
)


def _git(repo, *args, check=True):
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=check,
        capture_output=True,
        text=True,
    )


def _relative(path):
    value = PurePosixPath(path)
    if (
        value.is_absolute()
        or ".." in value.parts
        or ".git" in value.parts
        or not value.parts
    ):
        raise WorkspaceError(f"unsafe archive path: {path}")
    return value.as_posix()


def _safe_link_target(path, target):
    if os.path.isabs(target):
        raise WorkspaceError(f"absolute symlink target is not allowed: {path}")
    combined = posixpath.normpath(posixpath.join(posixpath.dirname(path), target))
    if combined == ".." or combined.startswith("../"):
        raise WorkspaceError(f"symlink escapes tree: {path} -> {target}")


def _digest(path):
    if path.is_symlink():
        return hashlib.sha256(os.readlink(path).encode()).hexdigest()
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _submodules(repo):
    entries = _git(repo, "ls-files", "-s").stdout.splitlines()
    if any(line.startswith("160000 ") for line in entries):
        raise WorkspaceError(
            "submodules are unsupported; refusing to misrepresent gitlinks"
        )
    for path in _git(repo, "ls-files", "-z").stdout.split("\0"):
        if not path:
            continue
        candidate = repo / path
        if not candidate.is_symlink() and candidate.is_file():
            with candidate.open("rb") as handle:
                prefix = handle.read(256)
            if prefix.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                raise WorkspaceError(
                    f"unresolved Git LFS pointer is unsupported: {path}"
                )


def _paths(repo, include_paths):
    tracked = _git(repo, "ls-files", "-z").stdout.split("\0")
    tracked = {p for p in tracked if p}
    selected = {_relative(p) for p in include_paths}
    unknown = (
        selected
        - tracked
        - {
            p
            for p in _git(
                repo, "ls-files", "-co", "--exclude-standard", "-z"
            ).stdout.split("\0")
            if p
        }
    )
    if unknown:
        raise WorkspaceError(
            f"--include-path is not in the working tree: {', '.join(sorted(unknown))}"
        )
    for path in sorted(tracked):
        if _SECRET.search(path) and path not in selected:
            raise WorkspaceError(
                f"tracked likely-secret path requires --include-path: {path}"
            )
    candidates = _git(repo, "ls-files", "-co", "--exclude-standard", "-z").stdout.split(
        "\0"
    )
    result = []
    for path in candidates:
        if not path or (_SECRET.search(path) and path not in selected):
            continue
        absolute = repo / path
        if absolute.exists() or absolute.is_symlink():
            result.append(path)
    return result, tracked


def _manifest(repo, paths, tracked):
    entries = []
    for path in paths:
        source = repo / path
        if source.is_symlink():
            _safe_link_target(path, os.readlink(source))
            try:
                source.resolve().relative_to(repo)
            except (ValueError, RuntimeError, OSError) as error:
                raise WorkspaceError(
                    f"symlink chain escapes source tree: {path}"
                ) from error
            kind = "symlink"
        elif source.is_file():
            kind = "file"
        else:
            raise WorkspaceError(f"unsupported working-tree entry: {path}")
        entries.append(
            {
                "path": path,
                "kind": kind,
                "mode": (source.stat() if kind == "file" else source.lstat()).st_mode
                & 0o7777,
                "sha256": _digest(source),
                **({"target": os.readlink(source)} if kind == "symlink" else {}),
            }
        )
    return {
        "format": 1,
        "run_id": "",
        "commit": _git(repo, "rev-parse", "HEAD").stdout.strip(),
        "tree": _git(repo, "rev-parse", "HEAD^{tree}").stdout.strip(),
        "entries": entries,
        "tracked": sorted(tracked),
    }


def prepare(repo, run_id, output, include_paths=()):
    repo = Path(repo).resolve()
    output = Path(output)
    if not repo.is_dir() or not (repo / ".git").exists():
        raise WorkspaceError(f"not a Git working tree: {repo}")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", run_id):
        raise WorkspaceError("run-id must be a safe identifier")
    _submodules(repo)
    paths, tracked = _paths(repo, include_paths)
    manifest = _manifest(repo, paths, tracked)
    manifest["run_id"] = run_id
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        dir=output.parent, prefix=f".{output.name}.", delete=False
    ) as handle:
        temporary = Path(handle.name)
    try:
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "git.bundle"
            _git(repo, "bundle", "create", str(bundle), "HEAD")
            with tarfile.open(temporary, "w") as archive:
                manifest_data = json.dumps(manifest, sort_keys=True).encode()
                archive.addfile(
                    _tar_info("manifest.json", manifest_data), io.BytesIO(manifest_data)
                )
                bundle_data = bundle.read_bytes()
                archive.addfile(
                    _tar_info("git.bundle", bundle_data), io.BytesIO(bundle_data)
                )
                for entry in manifest["entries"]:
                    try:
                        (repo / entry["path"]).resolve().relative_to(repo)
                    except (ValueError, RuntimeError, OSError) as error:
                        raise WorkspaceError(
                            "restored symlink chain escapes workspace"
                        ) from error
                for entry in manifest["entries"]:
                    source = repo / entry["path"]
                    name = f"tree/{entry['path']}"
                    if entry["kind"] == "symlink":
                        info = _tar_info(name, b"")
                        info.type = tarfile.SYMTYPE
                        info.linkname = entry["target"]
                        archive.addfile(info)
                    else:
                        data = source.read_bytes()
                        info = _tar_info(name, data)
                        info.mode = entry["mode"]
                        archive.addfile(info, io.BytesIO(data))
        os.replace(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)


def _tar_info(name, data):
    info = tarfile.TarInfo(name)
    info.size = len(data)
    info.mode = 0o600
    return info


def _read_archive(archive):
    try:
        tar = tarfile.open(archive, "r")
    except (tarfile.TarError, OSError) as error:
        raise WorkspaceError(f"invalid workspace archive: {error}") from error
    with tar:
        members = tar.getmembers()
        names = [_relative(member.name) for member in members]
        if len(names) != len(set(names)):
            raise WorkspaceError("archive contains duplicate paths")
        if "manifest.json" not in names or "git.bundle" not in names:
            raise WorkspaceError("archive lacks manifest.json or git.bundle")
        by_name = dict(zip(names, members))
        try:
            manifest = json.loads(tar.extractfile(by_name["manifest.json"]).read())
            tar.extractfile(by_name["git.bundle"]).read()
        except (AttributeError, json.JSONDecodeError) as error:
            raise WorkspaceError(f"invalid archive metadata: {error}") from error
        if manifest.get("format") != 1 or not isinstance(manifest.get("entries"), list):
            raise WorkspaceError("unsupported workspace manifest")
        for member, name in zip(members, names):
            if name in {"manifest.json", "git.bundle"}:
                if not member.isfile():
                    raise WorkspaceError(
                        f"archive metadata is not a regular file: {name}"
                    )
                continue
            if not name.startswith("tree/") or name == "tree/":
                raise WorkspaceError(f"unexpected archive path: {name}")
            path = name[5:]
            if member.issym():
                _safe_link_target(path, member.linkname)
            elif not member.isfile():
                raise WorkspaceError(f"unsupported archive entry: {name}")
        expected = {entry.get("path"): entry for entry in manifest["entries"]}
        if any(
            not isinstance(path, str) or _relative(path) != path for path in expected
        ):
            raise WorkspaceError("manifest contains an unsafe path")
        if set(expected) != {name[5:] for name in names if name.startswith("tree/")}:
            raise WorkspaceError("manifest and archive tree differ")
        return manifest


def receive(archive, root, run_id):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", run_id):
        raise WorkspaceError("run-id must be a safe identifier")
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    destination = root / run_id
    if destination.exists() or destination.is_symlink():
        raise WorkspaceError(f"workspace already exists: {run_id}")
    lock = _lock(root / ".workspace.lock")
    with lock:
        manifest = _read_archive(archive)
        if destination.exists() or destination.is_symlink():
            raise WorkspaceError(f"workspace already exists: {run_id}")
        with tempfile.TemporaryDirectory(dir=root, prefix=f".{run_id}.") as directory:
            staging = Path(directory)
            with tarfile.open(archive, "r") as tar:
                members = tar.getmembers()
                names = [_relative(member.name) for member in members]
                by_name = dict(zip(names, members))
                manifest = json.loads(tar.extractfile(by_name["manifest.json"]).read())
                bundle = staging / "git.bundle"
                bundle.write_bytes(tar.extractfile(by_name["git.bundle"]).read())
                repo = staging / "repo"
                repo.mkdir()
                _git(repo, "init", "-q")
                _git(repo, "fetch", "-q", str(bundle), "HEAD:refs/heads/base")
                _git(repo, "checkout", "-q", "base")
                if _git(repo, "rev-parse", "HEAD").stdout.strip() != manifest["commit"]:
                    raise WorkspaceError("bundle commit does not match manifest")
                # Remove checkout content before overlay: existing Git symlinks must
                # never redirect archive writes or conflict with snapshot symlinks.
                import shutil

                for child in repo.iterdir():
                    if child.name == ".git":
                        continue
                    if child.is_dir() and not child.is_symlink():
                        shutil.rmtree(child)
                    else:
                        child.unlink()
                snapshot_paths = {entry["path"] for entry in manifest["entries"]}
                for tracked in _git(repo, "ls-files", "-z").stdout.split("\0"):
                    if tracked and tracked not in snapshot_paths:
                        target = repo / tracked
                        target.unlink(missing_ok=True)
                for member, name in zip(members, names):
                    if not name.startswith("tree/"):
                        continue
                    relative = Path(name[5:])
                    target = repo / relative
                    if any(
                        parent.is_symlink()
                        for parent in target.parents
                        if parent != repo.parent
                    ):
                        raise WorkspaceError("archive path traverses a symlink")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if member.issym():
                        os.symlink(member.linkname, target)
                    else:
                        target.write_bytes(tar.extractfile(member).read())
                        target.chmod(member.mode & 0o7777)
                for entry in manifest["entries"]:
                    target = repo / entry["path"]
                    if entry["kind"] == "symlink":
                        if (
                            not target.is_symlink()
                            or os.readlink(target) != entry["target"]
                        ):
                            raise WorkspaceError(
                                f"restored symlink does not match manifest: {entry['path']}"
                            )
                    elif (
                        target.is_symlink()
                        or not target.is_file()
                        or _digest(target) != entry["sha256"]
                        or (target.stat().st_mode & 0o7777) != entry["mode"]
                    ):
                        raise WorkspaceError(
                            f"restored file does not match manifest: {entry['path']}"
                        )
                (repo / ".git/t3-test").mkdir(exist_ok=True)
                (repo / ".git/t3-test/manifest.json").write_text(
                    json.dumps(manifest, sort_keys=True), encoding="utf-8"
                )
                os.replace(repo, destination)
    return destination
