"""Deliver durable T3 notices through the live Matrix adapter and its E2EE store."""

import asyncio
import logging
import os

try:
    from agent.ciel_broker_client import broker_call
except ImportError:  # unit tests run outside the Hermes tree
    from broker_client import broker_call

POLL = 30
MAX_BACKOFF = 300


async def owner_only(adapter, room, owner):
    """True only for a room holding exactly the owner and this bot."""
    members = await adapter._client.get_joined_members(room)
    joined = getattr(members, "joined", members)
    if isinstance(joined, dict) and "joined" in joined:
        joined = joined["joined"]
    return isinstance(joined, dict) and set(map(str, joined)) == {
        owner,
        str(adapter._client.mxid),
    }


async def deliver(adapter, path, owner, call=broker_call):
    """Send each undelivered notice once the room is still the owner-only DM, then acknowledge it.

    Delivery is at-least-once: a crash between send and acknowledgement repeats
    the message after restart, but a notice is never dropped or sent elsewhere.
    """
    for notice in await asyncio.to_thread(call, path, "notices"):
        if not await owner_only(adapter, notice["room_id"], owner):
            logging.getLogger(__name__).warning(
                "Ciel notice %s withheld: room is not the owner-only DM", notice["id"]
            )
            continue
        result = await adapter.send(notice["room_id"], notice["body"])
        if result.success:
            await asyncio.to_thread(call, path, "ack", {"id": notice["id"]})


async def watch(adapter):
    path = os.environ.get("CIEL_BROKER_SOCKET")
    owner = os.environ.get("MATRIX_ALLOWED_USERS")
    if not path or not owner or "," in owner:
        return
    delay = POLL
    while True:
        try:
            await deliver(adapter, path, owner)
            delay = POLL
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            logging.getLogger(__name__).warning(
                "Ciel notification delivery deferred: %s", type(exc).__name__
            )
            delay = min(delay * 2, MAX_BACKOFF)
        await asyncio.sleep(delay)
