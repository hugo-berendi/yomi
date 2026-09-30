"""Exercise the generated startup imports against an isolated n8n database."""

import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys

n8n, enforced, seeded = sys.argv[1:]
root = Path(os.environ["TMPDIR"]) / "n8n-test"
root.mkdir()
database = root / "database.sqlite"
env = os.environ | {
    "N8N_USER_FOLDER": str(root),
    "STATE_DIRECTORY": str(root),
    "DB_SQLITE_DATABASE": str(database),
    "N8N_ENCRYPTION_KEY": "synthetic-regression-test-key",
    "N8N_DIAGNOSTICS_ENABLED": "false",
    "N8N_VERSION_NOTIFICATIONS_ENABLED": "false",
    "N8N_TEMPLATES_ENABLED": "false",
}


def run(*command):
    result = subprocess.run(command, env=env, capture_output=True, text=True)
    if result.returncode:
        print(result.stdout, result.stderr)
        result.check_returncode()


run(n8n, "user-management:reset")
run(enforced)
run(seeded)
with sqlite3.connect(database) as db:
    assert db.execute("SELECT count(*) FROM workflow_entity").fetchone()[0] == 2
    assert all(
        row[0] is None for row in db.execute("SELECT staticData FROM workflow_entity")
    ), "Fresh imports must not adopt stale runtime state from an export"
    db.execute(
        "UPDATE workflow_entity SET staticData = ?, name = 'Live edit'",
        (json.dumps({"global": {"cursor": 37, "dedup": ["already-sent"]}}),),
    )

for _ in range(2):
    run(enforced)
    run(seeded)
    with sqlite3.connect(database) as db:
        rows = db.execute("SELECT id, name, staticData FROM workflow_entity").fetchall()
        assert len(rows) == 2, "Repeated imports must not create duplicate workflows"
        for workflow_id, name, static_data in rows:
            assert json.loads(static_data) == {
                "global": {"cursor": 37, "dedup": ["already-sent"]}
            }, f"Startup import erased runtime state for {workflow_id}"
            expected_name = (
                "yomiEnforcedFixture"
                if workflow_id == "yomiEnforcedFixture"
                else "Live edit"
            )
            assert name == expected_name, "Enforced and seeded ownership changed"
