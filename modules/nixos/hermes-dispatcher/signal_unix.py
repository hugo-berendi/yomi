"""Narrow Hermes transport for signal-cli's private JSON-RPC Unix socket.

The upstream adapter expects an HTTP-shaped client. Keep that interface while
avoiding an unauthenticated TCP listener on the multi-service host.
"""

import asyncio
from contextlib import asynccontextmanager
import json
import os
import sqlite3
import uuid


def self_note(event, account):
    if not isinstance(event, dict) or event.get("account", account) != account:
        return None
    envelope = event.get("envelope")
    if not isinstance(envelope, dict) or envelope.get("sourceNumber") != account:
        return None
    sync = envelope.get("syncMessage")
    sent = sync.get("sentMessage") if isinstance(sync, dict) else None
    if not isinstance(sent, dict):
        return None
    if (sent.get("destinationNumber") or sent.get("destination")) != account:
        return None
    if sent.get("groupInfo") or sent.get("attachments") or sent.get("viewOnce"):
        return None
    if not isinstance(sent.get("message"), str) or not sent["message"].strip():
        return None
    if not isinstance(sent.get("timestamp"), int):
        return None
    return event


def validate_send(request, account):
    if not isinstance(request, dict) or request.get("method") not in {
        "send",
        "sendTyping",
    }:
        raise ValueError("Only text replies and typing to Note to Self are allowed")
    params = request.get("params")
    allowed = {
        "account",
        "recipient",
        "message",
        "textStyle",
        "textStyles",
        "quoteTimestamp",
        "quoteAuthor",
        "quoteMessage",
        "stop",
    }
    if not isinstance(params, dict) or set(params) - allowed:
        raise ValueError("Unsupported Signal parameters")
    recipients = params.get("recipient")
    if isinstance(recipients, str):
        recipients = [recipients]
    if params.get("account") != account or recipients != [account]:
        raise ValueError("Signal replies are restricted to the configured account")
    return request


class Response:
    status_code = 200

    def __init__(self, data=None):
        self.data = data

    def json(self):
        return self.data

    def raise_for_status(self):
        pass


class Events:
    def __init__(self, reader, writer, owner, initial=()):
        self.reader, self.writer, self.owner = reader, writer, owner
        self.initial = list(initial)

    async def aclose(self):
        self.writer.close()
        await self.writer.wait_closed()

    async def aiter_text(self):
        # A timeout must not cancel a partially received JSON line.
        pending = asyncio.create_task(self.reader.readline())
        try:
            while True:
                if self.initial:
                    line = self.initial.pop(0)
                else:
                    done, _ = await asyncio.wait({pending}, timeout=15)
                    if not done:
                        yield ": keepalive\n\n"
                        continue
                    line = pending.result()
                    if not line:
                        raise ConnectionError("Signal socket closed")
                    pending = asyncio.create_task(self.reader.readline())
                message = json.loads(line)
                if message.get("method") != "receive":
                    continue
                params = message.get("params", {})
                event = params.get("result", params)
                if self_note(event, self.owner.account):
                    timestamp = event["envelope"]["syncMessage"]["sentMessage"][
                        "timestamp"
                    ]
                    async with self.owner.send_lock:
                        echo = self.owner.sent.execute(
                            "SELECT 1 FROM sent WHERE timestamp = ?", (timestamp,)
                        ).fetchone()
                    if not echo:
                        yield "data: " + json.dumps(event) + "\n\n"
        finally:
            pending.cancel()
            await asyncio.gather(pending, return_exceptions=True)


class SignalUnixClient:
    def __init__(self, socket_path, account, ledger=None):
        self.socket_path, self.account = socket_path, account
        self.writers = set()
        self.send_lock = asyncio.Lock()
        self.sent = sqlite3.connect(
            ledger or os.getenv("YOMI_SIGNAL_LEDGER", ":memory:")
        )
        self.sent.execute(
            "CREATE TABLE IF NOT EXISTS sent (timestamp INTEGER PRIMARY KEY)"
        )
        self.sent.commit()

    @asynccontextmanager
    async def connection(self):
        reader, writer = await asyncio.wait_for(
            asyncio.open_unix_connection(self.socket_path, limit=1024 * 1024), 10
        )
        self.writers.add(writer)
        try:
            yield reader, writer
        finally:
            self.writers.discard(writer)
            writer.close()
            await writer.wait_closed()

    async def get(self, _url, **_kwargs):
        async with self.connection():
            return Response()

    async def post(self, _url, *, json, timeout=30):
        request = validate_send(json, self.account)
        async with (
            self.send_lock,
            asyncio.timeout(timeout),
            self.connection() as (reader, writer),
        ):
            writer.write((__import__("json").dumps(request) + "\n").encode())
            await writer.drain()
            while line := await reader.readline():
                reply = __import__("json").loads(line)
                if reply.get("id") == request.get("id"):
                    timestamp = (reply.get("result") or {}).get("timestamp")
                    if request["method"] == "send" and isinstance(timestamp, int):
                        self.sent.execute(
                            "INSERT OR IGNORE INTO sent VALUES (?)", (timestamp,)
                        )
                        self.sent.commit()
                    return Response(reply)
            raise ConnectionError("Signal RPC closed before replying")

    @asynccontextmanager
    async def stream(self, _method, _url, **_kwargs):
        async with self.connection() as (reader, writer):
            request_id = str(uuid.uuid4())
            writer.write(
                (
                    json.dumps(
                        {
                            "jsonrpc": "2.0",
                            "id": request_id,
                            "method": "subscribeReceive",
                            "params": {"account": self.account},
                        }
                    )
                    + "\n"
                ).encode()
            )
            await writer.drain()
            initial = []
            async with asyncio.timeout(30):
                while line := await reader.readline():
                    reply = json.loads(line)
                    if reply.get("id") == request_id:
                        if "error" in reply or "result" not in reply:
                            raise ConnectionError("Signal receive subscription failed")
                        break
                    if reply.get("method") == "receive":
                        params = reply.get("params", {})
                        if self_note(params.get("result", params), self.account):
                            initial.append(line)
                            if len(initial) > 100:
                                raise ConnectionError(
                                    "Too many events before subscription reply"
                                )
                else:
                    raise ConnectionError("Signal receive subscription closed")
            yield Events(reader, writer, self, initial)

    async def aclose(self):
        for writer in list(self.writers):
            writer.close()
        self.sent.close()
