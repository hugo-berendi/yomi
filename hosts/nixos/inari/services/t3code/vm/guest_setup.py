from bootstrap import run_remote


def configure_guest(key, known_hosts, tools_changed):
    unit = """[Unit]
After=network-online.target
Wants=network-online.target

[Service]
User=agent
WorkingDirectory=/home/agent
Environment=PATH=/opt/t3code-tools/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
ExecStart=/opt/t3code-tools/bin/t3 --host 10.231.0.2 --port 3773 --base-dir /home/agent/.t3 --no-browser --lan
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
"""
    previous = run_remote(
        key, known_hosts, ["cat", "/etc/systemd/system/t3code.service"], check=False
    )
    unit_changed = previous.returncode != 0 or previous.stdout != unit
    run_remote(
        key,
        known_hosts,
        [
            "sudo",
            "install",
            "-D",
            "-m",
            "644",
            "/dev/stdin",
            "/etc/systemd/system/t3code.service",
        ],
        input=unit,
    )
    run_remote(key, known_hosts, ["sudo", "systemctl", "daemon-reload"])
    run_remote(key, known_hosts, ["sudo", "systemctl", "enable", "t3code.service"])
    run_remote(
        key,
        known_hosts,
        [
            "sudo",
            "install",
            "-m",
            "644",
            "/dev/stdin",
            "/etc/profile.d/t3code-tools.sh",
        ],
        input="export PATH=/opt/t3code-tools/bin:$PATH\n",
    )
    active = run_remote(
        key,
        known_hosts,
        ["systemctl", "is-active", "--quiet", "t3code.service"],
        check=False,
    )
    if active.returncode != 0:
        run_remote(key, known_hosts, ["sudo", "systemctl", "start", "t3code.service"])
    elif tools_changed or unit_changed:
        run_remote(key, known_hosts, ["sudo", "systemctl", "restart", "t3code.service"])
    run_remote(
        key,
        known_hosts,
        [
            "python3",
            "-c",
            """
import json, pathlib, subprocess
home = pathlib.Path('/home/agent')
share = pathlib.Path('/opt/t3code-tools/share')
for directory, names in json.loads((share / 'skill-targets.json').read_text()).items():
    target = home / directory
    target.mkdir(parents=True, exist_ok=True)
    for name in names:
        link = target / name
        if link.is_symlink():
            link.unlink()
        if not link.exists():
            link.symlink_to(share / 'agent-skills' / name)
subprocess.run(['python3', str(share / 'install-skill-instructions.py'), str(home), str(share / 'linux-test-policy.txt')], check=True)
target = home / '.config/opencode/AGENTS.md'
target.parent.mkdir(parents=True, exist_ok=True)
policy = (share / 'linux-test-policy.txt').read_text()
begin, end = '<!-- BEGIN LINUX TESTING -->', '<!-- END LINUX TESTING -->'
old = target.read_text() if target.exists() else ''
if begin in old:
    first, rest = old.split(begin, 1)
    _, last = rest.split(end, 1)
    old = first + last
target.write_text(old.rstrip() + '\\n\\n' + begin + '\\n' + policy + end + '\\n')
""",
        ],
    )
