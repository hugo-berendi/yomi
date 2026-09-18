# Working on n8n workflows

This directory holds n8n workflow exports that `hosts/nixos/inari/services/n8n.nix`
imports on every service start (`yomi.n8n.workflows.<name>`). Read that file
first — it has the up-to-date mechanics. This is the "how do I add or change
one of these" guide the module comment doesn't have room for.

## The model

- n8n keeps workflows in its own sqlite database. The JSON in this directory
  is a mirror, imported via `n8n import:workflow` as an `ExecStartPre` on the
  `n8n` unit itself (DynamicUser, so only the unit's own processes get the
  right uid — see the comment above `importScript` in `n8n.nix`).
- Import upserts on the JSON's `id`. A missing `id` is a hard eval-time
  assertion, not a runtime surprise, because a missing id would create a
  duplicate workflow on every single restart instead of updating the existing
  one.
- **Activation is a separate step from import.** `n8n import:workflow
  --activeState=fromJson` is documented in `--help` but errors at runtime on
  this single-instance deployment ("can only be used ... in queue or
  multi-main mode"). `n8n.nix` reads the JSON's own `active` field at eval
  time and drives `publish:workflow` / `unpublish:workflow` afterwards
  instead. If a future n8n upgrade changes this again, the symptom is
  `journalctl -u n8n` showing the import step apparently succeed while
  nothing ends up active — check the actual publish/unpublish command output,
  not just "did import:workflow exit 0".
- `enforce = true` (the default) re-imports on every restart, so the repo
  always wins over anything edited live in the web UI. `enforce = false`
  seeds once and then leaves the web UI in control — use this while a
  workflow still needs a credential attached by hand (see below), then flip
  it to `true` once the workflow is stable and you've pulled a fresh export.

## Credentials never live in git

Credentials (SMTP, HTTP basic auth, …) stay in n8n's own encrypted store, not
in these JSON files or in sops — this repo is mirrored to a public forge. A
workflow JSON only carries a `credentials` block with an `id` + `name`
reference, e.g.:

```json
"credentials": { "smtp": { "id": "<n8n's real id>", "name": "Migadu (no-reply)" } }
```

When you add a node that needs a new credential, you cannot know its real id
ahead of time. Put a placeholder id in the JSON, set `enforce = false` so your
placeholder doesn't clobber the real one, ship it, then ask a human to open
the workflow in the web UI, create/attach the credential once, and confirm it
works. After that, run `just n8n-export` (needs interactive sudo — a human
has to run it, agents can't) to pull the real id back into the repo, fold in
any further edits on top of that export, and only then flip `enforce` back to
`true`.

## Verify against the live instance, not against docs or memory

n8n's CLI help text, node parameter shapes, and available metrics all drift
faster than any written guide (including this one). Before writing a new
workflow:

- **Read the installed node's schema directly** instead of guessing
  parameter names. It's in the nix store:
  `find /nix/store/*-n8n-*/lib/n8n/packages/nodes-base/dist/node-definitions -iname '*<nodeType>*'`
  — the `*.schema.js` files are the real, versioned Zod schema for that node's
  parameters at whatever n8n version is actually pinned here.
- **Query whatever the workflow will query, for real, before writing the
  query.** The health-monitor workflow's PromQL was built by curling
  `http://127.0.0.1:<port>/api/v1/query` on inari directly, checking actual
  metric names (`node_zfs_*` vs `zfs_*`, which labels exist, which values
  mean "healthy") and iterating on collisions in a real response — not by
  recalling what a generic node-exporter setup usually looks like. Port
  numbers are in `hosts/nixos/common/base/ports.nix`.
- **Test Code node JavaScript with plain `node` before pasting it into the
  workflow JSON.** Mock `this.helpers.httpRequest` and `$input`/
  `$getWorkflowStaticData` with realistic sample data, run it, and read the
  actual generated output (HTML, objects, whatever). This catches syntax
  errors, wrong-shape assumptions about API responses, and lets you eyeball
  a rendered email before it ever reaches n8n. See the git history of
  `health-monitor.json` / `webuntis-radicale.json` for the throwaway test
  harness pattern (a `Function('return (async function(){' + code + '})')`
  wrapper is enough — don't invent a heavier test setup).
- After changing `n8n.nix` or a workflow JSON: `just nixos-rebuild dry-build
  inari` first. After a real switch, read `journalctl -u n8n` — the import
  and publish/unpublish steps log to the unit under their own derivation-name
  process tags, and a failure there is silent to `nixos-rebuild` (the
  `ExecStartPre` lines are prefixed `-` on purpose, so a broken workflow
  doesn't take down n8n itself).

## Building a JSON workflow by hand

Prefer building/editing in the web UI and exporting with `just n8n-export`
whenever possible — hand-written workflow JSON is error-prone (node ids must
be unique, connections reference nodes by exact name, etc.). When you do have
to hand-edit or hand-author JSON (e.g. scripting a new node into an existing
export), use `jq` to splice fields rather than hand-escaping multi-line JS
into a JSON string — `jq --arg jsCode "$(cat script.js)" '...'` gets the
escaping right for free. Keep the top-level key order the way `just
n8n-export` produces it (`jq -S`) so future diffs stay small.

Generate node/workflow ids with `uuidgen` (nodes) or 16 random alnum
characters (workflow `id`, matching n8n's own nanoid-style ids) — anything
n8n hasn't already seen is fine, since import upserts by id.

## Email design language

Notification emails sent from workflows here (`health-monitor.json`,
`webuntis-radicale.json`) share one look: a dark "terminal" card (`#0b0f14`)
on a light neutral wrapper (`#eef1f5`), monospace throughout
(`ui-monospace,'JetBrains Mono','SFMono-Regular',Menlo,Consolas,'Liberation
Mono',monospace`), a thin colored status bar at the top, a `$ <command>`
prompt line under the header, bracket status tags (`[ OK ]`, `[WARN]`,
`[CRIT]`, `[ UP ]`, `[DOWN]`, `[ PUT ]`, `[ DEL ]`) rather than color alone,
and `# comment`-styled section headers. Reuse this rather than inventing a
new look per workflow — copy the palette object out of either Code node's
`jsCode` as a starting point. Everything is inline-styled table markup (no
`<style>` block, no external fonts) because that's what actually survives
Gmail/Apple Mail/Outlook clipping and dark-mode reprocessing.
