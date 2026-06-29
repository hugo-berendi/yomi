#!/usr/bin/env python3
"""MCP server for Radicale CalDAV calendar access."""

from __future__ import annotations

import os
from datetime import datetime, timedelta
from typing import Any

import caldav
from mcp.server.fastmcp import FastMCP

RADICALE_URL = os.environ.get("RADICALE_URL", "http://127.0.0.1:8468/")
CALENDAR_NAME = os.environ.get("RADICALE_CALENDAR", "hermes")

mcp = FastMCP("radicale")


def _client() -> caldav.DAVClient:
    return caldav.DAVClient(RADICALE_URL)


def _calendar() -> caldav.Calendar:
    client = _client()
    principal = client.principal()
    for cal in principal.calendars():
        if cal.name == CALENDAR_NAME:
            return cal
    return principal.make_calendar(name=CALENDAR_NAME)


def _render_json(obj: Any) -> str:
    import json

    return json.dumps(obj, ensure_ascii=False, default=_json_default)


def _json_default(obj: Any) -> str:
    if isinstance(obj, datetime):
        return obj.isoformat()
    return str(obj)


@mcp.tool()
def list_events(days: int = 30) -> str:
    """List calendar events within +/- N days from now."""
    cal = _calendar()
    now = datetime.now().astimezone()
    start = now - timedelta(days=days)
    end = now + timedelta(days=days)
    events = cal.date_search(start=start, end=end)
    result = []
    for event in events:
        vevent = event.vobject_instance.vevent
        result.append(
            {
                "uid": str(vevent.uid.value) if hasattr(vevent, "uid") else None,
                "summary": str(vevent.summary.value) if hasattr(vevent, "summary") else None,
                "start": str(vevent.dtstart.value) if hasattr(vevent, "dtstart") else None,
                "end": str(vevent.dtend.value) if hasattr(vevent, "dtend") else None,
                "description": str(vevent.description.value) if hasattr(vevent, "description") else None,
            }
        )
    return _render_json({"events": result})


@mcp.tool()
def create_event(summary: str, start: str, end: str, description: str = "") -> str:
    """Create a calendar event. Start/end are ISO datetimes, e.g. 2026-07-01T09:00:00."""
    cal = _calendar()
    dtstart = datetime.fromisoformat(start.replace("Z", "+00:00"))
    dtend = datetime.fromisoformat(end.replace("Z", "+00:00"))
    event = cal.save_event(
        dtstart=dtstart,
        dtend=dtend,
        summary=summary,
        description=description,
    )
    return _render_json({"success": True, "url": str(event.url)})


@mcp.tool()
def delete_event(uid: str) -> str:
    """Delete a calendar event by UID."""
    cal = _calendar()
    event = cal.event_by_uid(uid)
    event.delete()
    return _render_json({"success": True, "deleted": uid})


if __name__ == "__main__":
    mcp.run(transport="stdio")
