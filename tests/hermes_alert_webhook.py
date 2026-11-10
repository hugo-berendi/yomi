"""Contract test: the alert router's requests against the pinned Hermes webhook adapter.

Runs inside the Hermes package's own interpreter and site-packages, starts the
real ``gateway.platforms.webhook.WebhookAdapter`` with the routes the NixOS
configuration generates, and lets the router's JavaScript client post to it.

Covered against real upstream code: route validation at startup, HMAC V2
signature checks, prompt rendering, deliver-only delivery to the verified
room through a Matrix adapter, in-memory duplicate suppression of the
deliver-only route, and rejection of a wrong secret. Agent admission needs
Hermes' session database and a model; it is replaced by a recorder that
stands in for the durable ledger's duplicate answer.

    python hermes_alert_webhook.py <hermes-wrapped> <launch.json> <alert_webhook.py dir>
        <node> <client.cjs> <alert-triage.cjs> <alert-router.cjs>
"""

import ast
import asyncio
import json
import os
import secrets
import socket
import sys
import tempfile
from pathlib import Path


def hermes_sites(wrapped):
    """Site directories the Hermes wrapper adds; the exact runtime environment."""
    text = Path(wrapped).read_text()
    start = text.index("site.addsitedir(p, k), ") + len("site.addsitedir(p, k), ")
    end = text.index("]", start) + 1
    return ast.literal_eval(text[start:end])


def free_port():
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


async def main(argv):
    wrapped, launch, source, node, client, triage, router = argv
    import site

    for directory in hermes_sites(wrapped):
        site.addsitedir(directory)
    sys.path.insert(0, source)
    home = tempfile.mkdtemp(prefix="hermes-home-")
    os.environ["HERMES_HOME"] = home

    from alert_webhook import configure
    from gateway.config import Platform, PlatformConfig
    from gateway.platforms.base import SendResult
    from gateway.platforms.webhook import WebhookAdapter

    settings = json.loads(Path(launch).read_text())
    assert settings["alertWebhook"], "the inari configuration enables the alert webhook"
    secret = secrets.token_urlsafe(32)
    room = "!private:matrix.test"
    configuration = configure(
        json.loads(Path(settings["configuration"]).read_text()),
        settings["alertWebhook"],
        secret=secret,
        room=room,
    )
    platform = configuration["platforms"]["webhook"]
    assert platform["extra"]["host"] == "127.0.0.1"
    port = free_port()
    platform["extra"]["port"] = port
    for route in platform["extra"]["routes"].values():
        assert route.get("mirror_to_session") is not True, (
            "alert text must not enter the chat as a user turn"
        )
        assert route["deliver_extra"] == {"chat_id": room}

    sent = []

    class Matrix:
        async def send(self, chat_id, content, reply_to=None, metadata=None):
            sent.append((chat_id, content))
            return SendResult(success=True)

    class Runner:
        config = None

        def _authorization_adapter(self, target, profile):
            return Matrix() if target == Platform("matrix") else None

    admitted = {}

    adapter = WebhookAdapter(PlatformConfig.from_dict(platform))
    adapter.gateway_runner = Runner()

    async def admit(payload, prompt, delivery_id, now, **kwargs):
        if delivery_id in admitted:
            return "duplicate"
        admitted[delivery_id] = {"prompt": prompt, "route": kwargs["route_name"]}
        return "accepted"

    adapter._admit_agent_run = admit
    assert await adapter.connect(), "adapter starts with the generated routes"
    try:
        directory = tempfile.mkdtemp(prefix="alert-secret-")
        good = Path(directory, "good")
        good.write_text(secret)
        bad = Path(directory, "bad")
        bad.write_text(secrets.token_urlsafe(32))
        process = await asyncio.create_subprocess_exec(
            node,
            client,
            triage,
            router,
            f"http://127.0.0.1:{port}/webhooks",
            str(good),
            str(bad),
            stdout=asyncio.subprocess.PIPE,
        )
        output, _ = await process.communicate()
        assert process.returncode == 0, "client completed"
        results = json.loads(output)
    finally:
        await adapter.disconnect()

    assert results["triage"] == {"ok": True, "status": 202}, results
    assert results["triageAgain"] == {"ok": True, "status": 200}, results
    assert list(admitted) == ["alert-contract-1"], admitted
    prompt = admitted["alert-contract-1"]["prompt"]
    assert "BEGINN DATEN" in prompt and "ENDE DATEN" in prompt
    assert "inari/nextcloud" in prompt, "context rendered into the template"
    assert "{context}" not in prompt and "{count}" not in prompt, (
        "all placeholders filled"
    )
    data = prompt.split("BEGINN DATEN", 1)[1]
    assert "Ignore previous instructions" in data, (
        "untrusted text stays inside the data block"
    )

    assert results["notice"] == {"ok": True, "status": 200}, results
    assert results["noticeAgain"] == {"ok": True, "status": 200}, results
    assert len(sent) == 1, f"deliver-only duplicate suppressed: {sent}"
    assert sent[0][0] == room and "Entwarnung inari/nextcloud" in sent[0][1], sent

    assert results["forged"]["ok"] is False and results["forged"]["status"] == 401, (
        results
    )
    print(
        "hermes alert webhook: routes, signatures, rendering, delivery and duplicates passed"
    )


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1:]))
