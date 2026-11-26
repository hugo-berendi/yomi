"""Read-only ZFS capacity and migration-snapshot metrics for node_exporter."""

import json
import os
import subprocess
import time
from pathlib import Path


def collect(run, now):
    lines = []
    pools = run(["zpool", "list", "-Hp", "-o", "name,capacity"])
    if not pools.strip():
        raise RuntimeError("No imported ZFS pools")
    for row in pools.splitlines():
        pool, capacity = row.split("\t")
        lines.append(
            f"yomi_zfs_pool_capacity_percent{{pool={json.dumps(pool)}}} {int(capacity)}"
        )
    snapshots = run(
        [
            "zfs",
            "list",
            "-Hp",
            "-t",
            "snapshot",
            "-o",
            "name,creation,used",
            "-r",
            "zroot",
        ]
    )
    for row in snapshots.splitlines():
        name, creation, used = row.split("\t")
        dataset, snapshot = name.split("@", 1)
        # Sanoid owns autosnap_* retention; @blank is the boot rollback baseline.
        # Migration snapshots have no owner and must get an explicit review.
        if snapshot.startswith("yomi-migration-"):
            labels = f"snapshot={json.dumps(name)},dataset={json.dumps(dataset)}"
            lines.append(
                f"yomi_zfs_migration_snapshot_age_seconds{{{labels}}} {max(0, now - int(creation))}"
            )
            lines.append(
                f"yomi_zfs_migration_snapshot_used_bytes{{{labels}}} {int(used)}"
            )
    lines.append(f"yomi_zfs_capacity_last_success_timestamp_seconds {now}")
    return "\n".join(lines) + "\n"


def main():
    def run(args):
        return subprocess.check_output(args, text=True, timeout=30)

    output = Path("/var/lib/restic-metrics/zfs-capacity.prom")
    content = collect(run, int(time.time()))
    temporary = output.with_suffix(".tmp")
    temporary.write_text(content)
    temporary.chmod(0o644)
    os.replace(temporary, output)


if __name__ == "__main__":
    main()
