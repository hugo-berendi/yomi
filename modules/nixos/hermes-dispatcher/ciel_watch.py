"""Deliver durable T3 notices through the live Matrix adapter and its E2EE store."""

import asyncio
import logging
import os

from agent.ciel_broker_client import broker_call


async def watch(adapter):
    path = os.environ.get("CIEL_BROKER_SOCKET")
    owner = os.environ.get("MATRIX_ALLOWED_USERS")
    if not path or not owner or "," in owner:
        return
    while True:
        try:
            notices = await asyncio.to_thread(broker_call, path, "notices")
            for notice in notices:
                members = await adapter._client.get_joined_members(notice["room_id"])
                joined = getattr(members, "joined", members)
                if isinstance(joined, dict) and "joined" in joined:
                    joined = joined["joined"]
                if not isinstance(joined, dict) or set(map(str, joined)) != {
                    owner,
                    str(adapter._client.mxid),
                }:
                    continue
                result = await adapter.send(notice["room_id"], notice["body"])
                if result.success:
                    await asyncio.to_thread(
                        broker_call, path, "ack", {"id": notice["id"]}
                    )
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            logging.getLogger(__name__).warning(
                "Ciel notification delivery deferred: %s", type(exc).__name__
            )
        await asyncio.sleep(30)
