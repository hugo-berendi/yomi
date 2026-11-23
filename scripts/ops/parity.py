"""Compare what two revisions of this flake build, ignoring store-path hashes.

A plain drvPath comparison is useless here: every `${./file}` reference puts
the flake source store path into a derivation, and that path's hash changes
with any edit anywhere in the repository. This script dumps the full
derivation graph of each host's toplevel, rewrites the hashes of derivations,
their outputs and the flake source to a placeholder, and compares the graphs
by derivation name. What is left are the derivations whose inputs really
changed: a unit file, a config file, a package list, a script.

Copied sources (`${./file.py}`, `builtins.path`) keep their hashes, which
change exactly when their content or name does. A file read through a path
inside the flake source itself (`"${./.}/file"`) is not seen.

    parity.py [--base REV] [--new REV] [--host HOST ...] [--show N]

--base defaults to the merge base with origin/main. The new side is the
working tree as the flake sees it (tracked files, including uncommitted
edits), or the revision given with --new.

Normalised dumps are cached in ~/.cache/yomi-parity, about 100 MB per host
and revision; delete the directory whenever it grows too large.
"""

import argparse
import collections
import difflib
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys

HOSTS = ["inari", "amaterasu", "tsukuyomi", "wsl-work", "ebisu", "iso"]
STORE_HASH = re.compile(r"[0-9a-df-np-sv-z]{32}-")
GIT_REV = re.compile(r"\b[0-9a-f]{40}\b")
# The flake's own source differs between any two revisions by definition: its
# narHash, the commit time it reports as lastModified, and a rev that a dirty
# working tree does not have. A lock update changes far more than these, so
# blanking them for every input hides nothing.
SELF_SOURCE = [
    (re.compile(r'(\\?"narHash\\?":\\?")sha256-[A-Za-z0-9+/=]+'), r"\1NARHASH"),
    (re.compile(r'(\\?"lastModified\\?":)[0-9]+'), r"\g<1>0"),
    (re.compile(r',\\?"rev\\?":\\?"REV\\?"'), ""),
]
# A source path's basename: a content hash and a name.
SOURCE = re.compile(r"([0-9a-df-np-sv-z]{32})-(.+)")
# Part of the cache key, so a change to the normalisation discards old dumps.
NORMALISATION = "4"
CACHE = (
    pathlib.Path(os.environ.get("XDG_CACHE_HOME", pathlib.Path.home() / ".cache"))
    / "yomi-parity"
)


def run(args, **kw):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kw).stdout


def toplevel(ref, host):
    attr = f"{ref}#nixosConfigurations.{host}.config.system.build.toplevel.drvPath"
    return run(["nix", "eval", "--raw", "--accept-flake-config", attr]).strip()


def graph(drv):
    """name -> sorted list of normalised derivation JSON, cached by drvPath."""
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = CACHE / (
        hashlib.sha256((NORMALISATION + drv).encode()).hexdigest() + ".json"
    )
    if cached.exists():
        return json.loads(cached.read_text())
    data = json.loads(run(["nix", "derivation", "show", "-r", drv]))
    drvs = data.get("derivations", data)
    # Copied sources are content-addressed, so their hashes stay; the flake's
    # own source ("source") differs in every revision and is blanked with the
    # derivation and output hashes, which cascade from any change below them.
    kept = set()
    for value in drvs.values():
        for src in (value.get("inputs") or {}).get("srcs", []):
            match = SOURCE.fullmatch(src.rsplit("/", 1)[-1])
            if match and match.group(2) != "source":
                kept.add(match.group(1))

    def blank(match):
        digest = match.group(0)[:-1]
        return digest.upper() + "-" if digest in kept else "HASH-"

    by_name = collections.defaultdict(list)
    # Normalise each derivation on its own, after parsing: rewriting the raw
    # dump first would give same-named derivations the same JSON key, and the
    # parser would keep only one of them.
    for key, value in drvs.items():
        name = STORE_HASH.sub("", key.rsplit("/", 1)[-1], count=1)
        text = GIT_REV.sub(
            "REV", STORE_HASH.sub(blank, json.dumps(value, sort_keys=True))
        )
        for pattern, replacement in SELF_SOURCE:
            text = pattern.sub(replacement, text)
        value = json.loads(text)
        # Input sources are listed in store-path order, which the
        # placeholders above have just made meaningless.
        if isinstance(value.get("inputs"), dict) and "srcs" in value["inputs"]:
            value["inputs"]["srcs"] = sorted(value["inputs"]["srcs"])
        by_name[name].append(json.dumps(value, sort_keys=True))
    result = {name: sorted(values) for name, values in by_name.items()}
    cached.write_text(json.dumps(result))
    return result


def flat_inputs(inputs):
    inputs = inputs or {}
    srcs = {json.dumps(src, sort_keys=True) for src in inputs.get("srcs", [])}
    drvs = {
        f"{name} {json.dumps(out, sort_keys=True)}"
        for name, out in (inputs.get("drvs") or {}).items()
    }
    return srcs | drvs


def env_diff(old, new, limit):
    """Short description of how two normalised derivations differ."""
    a, b = json.loads(old), json.loads(new)
    lines = []
    for key in sorted(set(a.get("env", {})) | set(b.get("env", {}))):
        x, y = a.get("env", {}).get(key), b.get("env", {}).get(key)
        if x == y:
            continue
        if x is None or y is None:
            lines.append(f"    env.{key}: {'added' if x is None else 'removed'}")
            continue
        diff = list(
            difflib.unified_diff(x.splitlines(), y.splitlines(), lineterm="", n=1)
        )[2:]
        lines.append(f"    env.{key}:")
        lines.extend(
            "      " + (line if len(line) <= 160 else line[:160] + " …")
            for line in diff[:limit]
        )
        if len(diff) > limit:
            lines.append(f"      ... {len(diff) - limit} more lines")
    if a.get("inputs") != b.get("inputs"):
        old_in, new_in = flat_inputs(a.get("inputs")), flat_inputs(b.get("inputs"))
        lines.extend(f"    input - {x}" for x in sorted(old_in - new_in)[:limit])
        lines.extend(f"    input + {x}" for x in sorted(new_in - old_in)[:limit])
    for key in ("args", "builder", "outputs"):
        if a.get(key) != b.get(key):
            lines.append(f"    {key} differ")
    return lines


def compare(host, base_ref, new_ref, show):
    old_drv, new_drv = toplevel(base_ref, host), toplevel(new_ref, host)
    if old_drv == new_drv:
        print(f"{host}: identical derivation")
        return True
    old, new = graph(old_drv), graph(new_drv)
    changed = []
    for name in sorted(set(old) | set(new)):
        a, b = old.get(name, []), new.get(name, [])
        if a == b:
            continue
        changed.append((name, a, b))
    if not changed:
        print(f"{host}: identical after normalising store hashes")
        return True
    print(f"{host}: {len(changed)} derivation(s) differ")
    for name, a, b in changed:
        if not a:
            print(f"  + {name}")
        elif not b:
            print(f"  - {name}")
        else:
            # Several derivations can share a name; diff the ones that moved.
            only_a = [x for x in a if x not in b]
            only_b = [x for x in b if x not in a]
            count = f" ({len(only_b)} of {len(b)} with this name)" if len(b) > 1 else ""
            print(f"  ~ {name}{count}")
            if show and len(only_a) == 1 and len(only_b) == 1:
                for line in env_diff(only_a[0], only_b[0], show):
                    print(line)
    return False


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--base",
        help="git revision to compare against (default: merge base with origin/main)",
    )
    parser.add_argument(
        "--new",
        help="git revision to compare (default: the working tree, including uncommitted edits)",
    )
    parser.add_argument(
        "--host",
        action="append",
        choices=HOSTS,
        help="host to compare (repeatable; default: all)",
    )
    parser.add_argument(
        "--show",
        type=int,
        default=12,
        help="diff lines per changed variable (0 = names only)",
    )
    args = parser.parse_args()

    repo = run(["git", "rev-parse", "--show-toplevel"]).strip()
    base = args.base or run(["git", "merge-base", "HEAD", "origin/main"]).strip()
    base = run(["git", "rev-parse", base]).strip()
    base_ref = f"git+file://{repo}?rev={base}"
    if args.new:
        new = run(["git", "rev-parse", args.new]).strip()
        new_ref = f"git+file://{repo}?rev={new}"
        print(f"base {base[:12]}  vs  {new[:12]}")
    else:
        new_ref = f"git+file://{repo}"
        print(f"base {base[:12]}  vs  working tree of {repo}")
    results = [
        compare(host, base_ref, new_ref, args.show) for host in args.host or HOSTS
    ]
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
