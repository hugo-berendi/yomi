## Efficient delegation on Inari

Keep the user's current main model. Use cheaper subagents for genuinely separate, bounded tasks: finding relevant files, short documentation lookups, log triage, mechanical changes with a clear acceptance check, and targeted tests. Do a trivial one-step task or dependent sequence yourself; spawning extra agents is not automatically cheaper.

- Use GPT and Claude models for subagents: a small one for bounded routine work, a stronger one only for a substantial independent task or a review that needs it. Never use GitHub Copilot Auto as a default, baseline or fallback.
- Codex: use the fast_task role (@codex.cheap@ at @codex.cheapEffort@ reasoning) for routine delegated work; it is also the configured subagent default. Do difficult diagnosis, architecture, security decisions and final review in the parent.
- Claude Code: use fast-task (@claude.cheap@) for routine work and quick-review (@claude.review@) for a bounded review needing more reasoning. Do not send complex planning to fast-task.
- T3 Code: follow its current orchestration rules for choosing between the native subagent tool and `delegate_task`, and pick the models above from the live catalog.
- Give each child a small scope, relevant paths, constraints and an observable completion check. Send only necessary context. Start with one worker; use a second only for independent work that justifies its extra usage. Avoid nested delegation and duplicate investigations.
- Ask for compact results with evidence, changed paths and unresolved issues. The parent checks important claims and edits, and runs the required final validation. Preserve all existing permissions and approval requirements. Never expose credentials or delegate privilege changes merely to get around a restriction.
