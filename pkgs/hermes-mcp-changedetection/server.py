#!/usr/bin/env python3
"""MCP server for changedetection.io watch management."""

from __future__ import annotations

import os
from datetime import datetime
from typing import Any

import requests
from mcp.server.fastmcp import FastMCP

BASE_URL = os.environ.get("CHANGEDETECTION_BASE_URL", "http://127.0.0.1:8492").rstrip("/")

mcp = FastMCP("changedetection")


def _api(path: str) -> str:
    return f"{BASE_URL}/api/v1{path}"


def _safe_get(url: str) -> dict[str, Any]:
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    return resp.json()


def _safe_post(url: str, json: dict[str, Any]) -> dict[str, Any]:
    resp = requests.post(url, json=json, timeout=30)
    resp.raise_for_status()
    return resp.json()


def _safe_delete(url: str) -> None:
    resp = requests.delete(url, timeout=30)
    resp.raise_for_status()


@mcp.tool()
def list_watches() -> str:
    """List all change-detection watches."""
    data = _safe_get(_api("/watch"))
    watches = [
        {
            "uuid": uuid,
            "title": watch.get("title"),
            "url": watch.get("url"),
            "last_checked": watch.get("last_checked"),
            "viewed": watch.get("viewed"),
        }
        for uuid, watch in data.items()
    ]
    return _render_json({"watches": watches})


@mcp.tool()
def create_watch(url: str, title: str = "", tags: str = "") -> str:
    """Create a new change-detection watch for a URL."""
    payload: dict[str, Any] = {"url": url}
    if title:
        payload["title"] = title
    if tags:
        payload["tags"] = tags
    result = _safe_post(_api("/watch"), payload)
    return _render_json({"success": True, "watch": result})


@mcp.tool()
def delete_watch(uuid: str) -> str:
    """Delete a change-detection watch by UUID."""
    _safe_delete(_api(f"/watch/{uuid}"))
    return _render_json({"success": True, "deleted": uuid})


@mcp.tool()
def watch_history(uuid: str) -> str:
    """Get snapshot history for a watch by UUID."""
    result = _safe_get(_api(f"/watch/{uuid}/history"))
    return _render_json({"uuid": uuid, "history": result})


def _render_json(obj: Any) -> str:
    import json

    return json.dumps(obj, ensure_ascii=False, default=_json_default)


def _json_default(obj: Any) -> str:
    if isinstance(obj, datetime):
        return obj.isoformat()
    return str(obj)


if __name__ == "__main__":
    mcp.run(transport="stdio")
