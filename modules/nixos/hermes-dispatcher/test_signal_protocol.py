import asyncio
import json
from pathlib import Path
import tempfile
import unittest

from signal_unix import SignalUnixClient


class SignalProtocolTests(unittest.IsolatedAsyncioTestCase):
    async def test_subscription_filters_before_model_and_preserves_rpc_replies(self):
        account = "+491234567890"
        received = []

        async def daemon(reader, writer):
            try:
                line = await reader.readline()
                if not line:
                    return
                request = json.loads(line)
                received.append(request)
                if request["method"] == "subscribeReceive":
                    replies = [{"jsonrpc": "2.0", "id": request["id"], "result": 0}]
                    for sender in ("+499999999999", account):
                        replies.append(
                            {
                                "jsonrpc": "2.0",
                                "method": "receive",
                                "params": {
                                    "subscription": 0,
                                    "result": {
                                        "account": account,
                                        "envelope": {
                                            "sourceNumber": sender,
                                            "syncMessage": {
                                                "sentMessage": {
                                                    "destinationNumber": account,
                                                    "timestamp": 123,
                                                    "message": "Inspect login",
                                                }
                                            },
                                        },
                                    },
                                },
                            }
                        )
                    early = json.loads(json.dumps(replies[-1]))
                    early["params"]["result"]["envelope"]["syncMessage"]["sentMessage"][
                        "timestamp"
                    ] = 321
                    replies.insert(0, early)
                    if any(r["method"] == "send" for r in received):
                        echo = json.loads(json.dumps(replies[-1]))
                        echo["params"]["result"]["envelope"]["syncMessage"][
                            "sentMessage"
                        ]["timestamp"] = 456
                        replies.insert(2, echo)
                    for reply in replies:
                        writer.write((json.dumps(reply) + "\n").encode())
                    await writer.drain()
                    await reader.read()
                else:
                    writer.write(
                        (
                            json.dumps(
                                {"id": request["id"], "result": {"timestamp": 456}}
                            )
                            + "\n"
                        ).encode()
                    )
                    await writer.drain()
            finally:
                writer.close()
                await writer.wait_closed()

        with tempfile.TemporaryDirectory() as directory:
            socket = str(Path(directory) / "signal.sock")
            server = await asyncio.start_unix_server(daemon, socket)
            ledger = str(Path(directory) / "sent.sqlite")
            client = SignalUnixClient(socket, account, ledger)
            try:
                response = await client.get("http://signal/api/v1/check")
                self.assertEqual(response.status_code, 200)
                async with client.stream(
                    "GET", "http://signal/api/v1/events"
                ) as stream:
                    events = stream.aiter_text()
                    data = await asyncio.wait_for(anext(events), 2)
                    self.assertIn('"sourceNumber": "+491234567890"', data)
                    self.assertNotIn("+499999999999", data)
                    self.assertIn('"timestamp": 321', data)
                    self.assertIn(
                        '"timestamp": 123', await asyncio.wait_for(anext(events), 2)
                    )
                    await events.aclose()
                response = await client.post(
                    "http://signal/api/v1/rpc",
                    json={
                        "id": "reply",
                        "method": "send",
                        "params": {
                            "account": account,
                            "recipient": [account],
                            "message": "Done",
                        },
                    },
                )
                self.assertEqual(
                    response.json(), {"id": "reply", "result": {"timestamp": 456}}
                )
                await client.aclose()
                client = SignalUnixClient(socket, account, ledger)
                async with client.stream(
                    "GET", "http://signal/api/v1/events"
                ) as stream:
                    events = stream.aiter_text()
                    data = await asyncio.wait_for(anext(events), 2)
                    self.assertIn('"timestamp": 321', data)
                    self.assertIn(
                        '"timestamp": 123', await asyncio.wait_for(anext(events), 2)
                    )
                    await events.aclose()
                with self.assertRaises(ValueError):
                    await client.post(
                        "http://signal/api/v1/rpc",
                        json={
                            "id": "blocked",
                            "method": "listContacts",
                            "params": {},
                        },
                    )
                self.assertEqual(
                    [r["method"] for r in received],
                    ["subscribeReceive", "send", "subscribeReceive"],
                )
            finally:
                await client.aclose()
                server.close()
                await server.wait_closed()


if __name__ == "__main__":
    unittest.main()
