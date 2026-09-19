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

Credentials are shared instance-wide, not per-workflow. If a second workflow
needs the same credential (e.g. another node wants to send mail through the
same SMTP account), reuse the id you already learned from the first export
instead of seeding a second placeholder and doing the manual-attach dance
again.

`just n8n-export` overwrites this directory with **every** workflow in the
instance, filed under a filename it derives by slugifying the workflow's
`name` (lowercase, non-`a-z0-9-` characters dropped — so `ö`/`ü` etc. just
vanish, e.g. "persönlicher" becomes "persnlicher"). That slug essentially
never matches the short, hand-picked filenames these files actually use
(`health-monitor.json`, not `inari-health-monitor--tagesbericht-per-e-mail.json`),
and it exports unrelated workflows too (anything else that exists in the
instance, e.g. scratch workflows nobody registered in `n8n.nix`). After
running it: diff the freshly-slugified file against the real one for whatever
you changed, fold in what's new (usually just a credential id), and delete
the export's stray files rather than committing them — `git status` will
show them as untracked, they are not automatically part of anything.

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

**One palette, one look per kind of mail.** Every digest from this instance is
Rosé Pine Moon -- the same base16 scheme the desktops use, `rose-pine-moon`
via `common/themes/default.nix`. Structure, typography and voice still change
per digest; colour does not. An earlier version of this guide said the
opposite in both directions (first one look everywhere, then a palette per
mail); this is the settled answer.

Read the values out of the scheme rather than retyping them:

```bash
cat "$(nix build --no-link --print-out-paths nixpkgs#base16-schemes)/share/themes/rose-pine-moon.yaml"
```

| Role | Hex | Base16 |
|------|-----|--------|
| page ground | `#232136` | base00 |
| card surface | `#2a273f` | base01 |
| rules, inactive bar | `#393552` | base02 |
| muted text | `#6e6a86` | base03 |
| secondary text | `#908caa` | base04 |
| body text | `#e0def4` | base05 |
| **critical / failed** | `#eb6f92` love | base08 |
| **warning** | `#f6c177` gold | base09 |
| accent, arrivals | `#ea9a97` rose | base0A |
| structure, drafting | `#3e8fb0` pine | base0B |
| **ok / passing** | `#9ccfd8` foam | base0C |
| headings | `#c4a7e7` iris | base0D |

**Status colour is fixed across every digest**: foam is fine, gold wants a
look, love wants an action. A reader should not have to relearn the colours
per mail.

What still differs per digest, and should:

| Kind | Workflow | Voice |
|------|----------|-------|
| Ops / alarm | `health-monitor.json` | Console: monospace rows, iris headings, gauges |
| Ops / ledger | `backup-storage.json` | Gold headings, backup sets as cards, capacity bars |
| Arrivals | `media-arrivals.json` | Cinema ticket: Georgia, rose marquee, poster art |
| Build state | `forgejo-ci.json` | Blueprint: foam linework, revision log, title block |
| Timetable sync | `webuntis-radicale.json` | Change ledger: `[ PUT ]` / `[ DEL ]` rows |
| Your own post | `inbox-organizer.json` | Sorting office: iris bands, rubber stamps, torn stub |

The palette object is copied into all six Code nodes because n8n Code nodes
cannot import anything. Change one, change the rest.

Whatever the voice, these are not stylistic:

- **Inline styles on table markup only.** No `<style>` block, no external
  fonts, no flexbox or grid. That is what survives Gmail/Apple Mail/Outlook
  clipping and dark-mode reprocessing.
- **Only fonts installed everywhere.** Georgia, Courier New, Trebuchet MS,
  Verdana, and the `ui-monospace` stack. A webfont `<link>` is stripped by
  Gmail and most of Outlook, and the fallback is what your reader sees.
- **600px, and check it.** Long free-form text beside a
  `white-space:nowrap` value silently pushes the card past the width every
  client crops at, and a heading cell missing `colspan` will eat a whole
  column's width. Both happened here and neither was visible in the source.
- **Never colour alone.** Bracket tags, stamps or wording must carry the
  status too -- for colour-blind readers and for clients that rewrite
  backgrounds in dark mode.
- **Bars out of two table cells**, never a background image or a run of block
  glyphs: Outlook drops the first and mismeasures the second.
- **Only draw a bar for a real proportion.** A full-width bar under "zpool
  ONLINE" reads as a meter pinned at 100%, which is a measurement nobody
  made. Hairline those rows instead.
- **Images must be absolute public URLs.** A nix store path or a
  `127.0.0.1` URL is a broken image in every mail client. Design the
  no-image fallback too.

### Render it before you commit it

Screenshot the HTML rather than trusting the markup. Every digest here has had
at least one layout bug that was invisible in the source and obvious in a
render.

```bash
node harness.js                      # writes preview.html, see the section above
nix run nixpkgs#chromium -- --headless --disable-gpu --hide-scrollbars \
  --window-size=680,900 --screenshot=preview.png file://$PWD/preview.html
```

A bare nix chromium has no fontconfig, so every serif silently falls back to
mono and you are not reviewing your own typography. Point it at a font set
first:

```bash
# fonts.conf aliasing Georgia -> Liberation Serif, Courier New -> Liberation Mono
FONTCONFIG_FILE=$PWD/fonts.conf nix shell nixpkgs#chromium -c chromium --headless ...
```

Glyph coverage is part of this: `U+2713`/`U+2715` rendered as tofu boxes and
had to become `[+]`/`[X]`.

## Code nodes have no `process`

n8n runs Code nodes in its JS task runner, which evaluates them in a `vm`
context built from an explicit list. **There is no `process`** -- read
environment variables with **`$env.VARIABLE`**.

`$env` also has to be unblocked, which is a separate thing from using it.
n8n refuses env access in Code nodes by default: `createEnvProviderState()`
treats anything but the exact string `false` as blocked, and the node fails
with **`access to env vars denied`**. `n8n.nix` sets
`N8N_BLOCK_ENV_ACCESS_IN_NODE = lib.boolToString false` -- `lib.boolToString`
rather than `toString`, because `toString false` is `""` in Nix, which leaves
access blocked while looking like it was turned off.

That flag hands every Code node the unit's whole environment, secrets
included. It is what these workflows need and what they had under
`process.env`, but a Code node added through the web ui can read every
secret the unit holds.

The absence is specific, not general. `getNativeVariables()` in the runner
injects `Buffer`, `setTimeout`/`setInterval`/`setImmediate` and their
clears, `btoa`/`atob`, `TextEncoder`/`TextDecoder` and the stream variants;
`require` exists behind an allowlisting resolver, and the code wrapper
defines `global` as `globalThis`. So `Buffer.byteLength` in
`webuntis-radicale.json` is fine. Check the list before assuming something
is unavailable:

```bash
sed -n "/getNativeVariables()/,/}/p" \
  /nix/store/*-n8n-*/lib/n8n/packages/@n8n/task-runner/dist/js-task-runner/js-task-runner.js
```

This deserves its own section because of how it fails. `$env` is fine, but
`process.env.FOO` throws `ReferenceError: process is not defined` -- and
these workflows catch their own errors, so the digest arrives looking
perfectly healthy while reporting every service unreachable. It broke the
webuntis sync silently for however long, and an earlier version of this
guide told you to use the broken form.

Two guards exist now, because neither alone was enough:

- An eval-time assertion in `n8n.nix` rejects any workflow whose Code node
  mentions the old accessor, so `nix flake check` catches it.
- **Test Code nodes in a real `vm` context, not `new Function`.** A
  `new Function` harness inherits the host process globals, so the broken
  form works there and the bug is invisible until production. Mirror the
  runner instead:

  ```js
  const vm = require("node:vm");
  const sandbox = vm.createContext({
    __isExecutionContext: true,
    $env: new Proxy({}, { get: (_, k) => process.env[k] }),
  });
  ```

  The runner's own construction is in the store and worth re-reading after
  an upgrade:
  `packages/@n8n/task-runner/dist/js-task-runner/js-task-runner.js`.

## Workflows that call a model

`inbox-organizer.json` classifies mail against the small llama.cpp defined in
`hosts/nixos/inari/services/llama-cpp-classifier.nix`, reached through
`CLASSIFIER_URL` in `services.n8n.environment`. If you add another
model-using workflow, read that module's comment first: it records which
models were measured and why the 3B won.

- **Choose the model by measuring, not by reputation.** Write a labelled set
  of a dozen realistic cases, run the candidates against it, and keep the
  numbers. The 1.7B looked like the obvious pick on size and was wrong in the
  way that costs: it filed a doctor's appointment as unsolicited bulk.
- **Fix systematic errors with a rule, not a longer prompt.** Both candidates
  read a DHL parcel as travel, because `Sendung` means both. Carriers are a
  closed list. A rule is faster, cannot drift, and is reviewable in git.
- **Never trust the model's numbers.** Small models rate scam mail as urgent,
  because urgency is how scam mail is written. Clamp by bucket.
- **Reject unknown labels.** A hallucinated bucket would quietly invent a
  category nobody designed; the 1.7B answered `news` for `newsletters`.
  Validate against the taxonomy and record the miss instead.
- **A model being down must not lose data.** The classifier records the mail
  with an `unsorted` verdict and the error text, so the digest cannot silently
  under-report the inbox.
- **This box has no GPU and ten busy cores.** Budget seconds per call, cap
  threads, and keep the prompt short: the body excerpt is truncated to 400
  characters precisely so `--ctx-size` can stay at 4096.
