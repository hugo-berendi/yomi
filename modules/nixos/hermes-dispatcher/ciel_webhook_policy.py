"""Codex settings for unattended webhook turns: analysis only, no actions.

Ciel's Codex home registers the ``ciel`` MCP server with its task tools
pre-approved, because Hugo authorized them for his own chat. A webhook turn is
not Hugo: its prompt carries alert context that includes journal lines, which
anyone who can make a service log something can influence. Such a turn must
not be able to start, answer or stop T3 tasks, and must not read local files
that its answer or a web search could carry out.

Codex reads these as per-process configuration overrides, and Hermes spawns
one Codex app-server per agent, so the restriction applies to webhook sessions
only and leaves Hugo's chat untouched.
"""

import functools

WEBHOOK_CODEX_ARGS = (
    "-c",
    "mcp_servers.ciel.enabled=false",
    "-c",
    "features.shell_tool=false",
    "-c",
    "features.unified_exec=false",
    # Known upstream regressions are often only findable on the web. The
    # prompt allows one search, and only for a specific error signature.
    "-c",
    'web_search="live"',
)


def is_webhook_agent(agent):
    platform = str(getattr(agent, "platform", "") or "").lower()
    user = str(getattr(agent, "user_id", "") or "")
    return platform == "webhook" or user.startswith("webhook:")


def client_factory(agent, base):
    """The Codex client factory for this agent, or None for the default."""
    if not is_webhook_agent(agent):
        return None
    return functools.partial(base, extra_args=list(WEBHOOK_CODEX_ARGS))
