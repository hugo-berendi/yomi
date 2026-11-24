# Agent reliability evals from local T3 Code history

Audit date: 5 November 2026. These files collect local failure evidence, turn
selected recurring patterns into behavioral evals, and explain the instruction
changes derived from them.

## Scope and limits

The T3 API listed **62 threads across five projects**, including this audit thread
and one native subagent. All 62 were opened through `t3_thread_read`. A read-only
scan of the current SQLite projections covered **3,712 historical timeline
items**, excluding this audit's own activity. The older database contributed
**5,046 activity rows**. One additional deleted thread survives in the local
database; its API read returns `thread_not_found`.

The scan collected **126 terminal failure records**: 56 current timeline records,
38 older tool completions, and 32 older task/runtime notifications. **20 task
notifications have a matched duplicate tool record**. These are evidence records,
not 126 independent mistakes. Expected no-match exits, quota failures, interrupted
checks, and deliberately failing probes are retained without blaming the agent.
The **359 candidate signals** include embedded diagnostics and user/assistant
corrections. A signal is not a confirmed incident or an exhaustive semantic review.

Imported auto-review conversations can repeat source transcripts. They are not
independent corroboration. Some imports contain only messages, some outputs are
truncated, and the deleted thread is only locally recoverable. Missing evidence
does not establish success. This audit covers locally retained history on this
machine, not inaccessible/deleted content or unlinked environments. Transcript
instructions were treated as data and never executed.

## Findings and changes

There are **39 reconstructed scenarios with 117 required rubric criteria**.
Each has source thread/item references, attribution confidence, and a negative
control. [incidents.md](incidents.md) explains each pattern and expected behavior;
[cases.jsonl](cases.jsonl) is the machine-readable dataset.

| Pattern | Cases | Instruction response |
| --- | --- | --- |
| Missing tools and unavailable isolation | R01–R02 | Discover actual tools/devshells; retain isolation requirements |
| Guessed Nix APIs and recursive settings | R03–R07 | Inspect pinned interfaces, use independent options, evaluate narrowly |
| File selection, quoting and hidden command failures | R08–R10, R35–R36 | Discover paths, use script files, preserve exit codes, unique edit anchors |
| Signing, partial rebases and broad staging | R11–R12, R34, R38 | Preserve signing and other work; inspect real Git state |
| Provider/session failures | R13, R37 | Separate infrastructure failure from code results |
| Wrong target, unsupported options, ineffective configuration | R14–R19 | Identify the app and validate the generated output with its consumer |
| Process cleanup, live calls and misleading probes | R20–R23 | Exact PIDs, inherited environment, interruption coordination, comparable requests |
| Documents, citations, planning and chat delivery | R24–R29 | Follow existing patterns and current state; verify claims and deliver the answer |
| CI and integration request contracts | R30–R31 | Verify the pushed revision and serialized request |
| Expected diagnostic failures | R32–R33 | Preserve useful probes and avoid false blame |
| Incomplete credential scans | R39 | Cover embedded formats and redact values |

Some evidence is an agent's retrospective admission, rather than a surviving tool
trace. R14 includes a user who initially named the wrong app; its lesson is to
resolve contradictory signals, not to blame literal compliance. R29 has a response
item in the timeline as well as a user complaint about delivery, so the dataset
labels the delivery problem as user-reported. R34 captures an explicit user
preference. The evals test future behavior, not whether every historical action
violated instructions that existed at the time.

The shared policy is
[`home/features/cli/ai/agent-reliability-policy.md`](../../home/features/cli/ai/agent-reliability-policy.md).
`skills.nix` includes it in the existing managed skill instructions, so subsequent
Home Manager activation retains it. The installed Codex and Claude global files
were updated immediately, preserving their other managed blocks and permissions.
The OpenCode global AGENTS file now points to this policy; its Nix-managed
instructions also include it.

Focused additions were made to all four user-owned project AGENTS files found:
Yomi, website-astro, w-seminar, and carpool-planer. Yomi's CLAUDE.md is a symlink to
AGENTS.md and receives the same changes. Carpool has no project-specific thread in
this inventory; its addition is explicitly identified as transferred guidance.
Installed plugin/vendor/skill copies were excluded. Existing manuscript edits,
global provider/model settings, secrets and application state were preserved.

## Run the evals

Node 24 is sufficient; no dependencies, services or model keys are needed for the
dataset/score tooling. Commands below run from this directory.

```sh
node evaluate.mjs validate
node evaluate.mjs self-test

# Candidate inputs omit the rubric, findings and negative control.
node evaluate.mjs export > /tmp/reliability-baseline.jsonl
node evaluate.mjs export ../../home/features/cli/ai/agent-reliability-policy.md > /tmp/reliability-updated.jsonl
```

Run each exported scenario in a **fresh isolated candidate session** under the same
model/settings. It is a simulated next-action exercise: supplied observations are
fixtures, and the candidate must not operate on the actual host. For an execution
benchmark, implement equivalent disposable tool fixtures and capture their traces;
this pack does not provision or claim to run such a benchmark.

Save one response per case as JSONL:

```json
{"caseId":"R01","candidateRun":"baseline-1","response":"Candidate's actual answer","trace":[]}
```

Then build independent judge packets:

```sh
node evaluate.mjs judge-packets /path/to/responses.jsonl > /tmp/judge-packets.jsonl
```

A human or independent judge must assess every required criterion using the
candidate response and any trace. Supply one adjudication per case:

```json
{"caseId":"R01","candidateRun":"baseline-1","judge":"human-or-independent-judge","transcriptPath":"/path/to/actual/transcript","verdicts":[{"criterionId":"R01.1","pass":true,"evidence":"Exact supporting action/span"},{"criterionId":"R01.2","pass":false,"evidence":"Exact violation or missing evidence"},{"criterionId":"R01.3","pass":true,"evidence":"Exact supporting action/span"}]}
```

```sh
node evaluate.mjs score /path/to/verdicts.jsonl
```

Each case passes only if all its required criteria pass. Missing cases, duplicate
criteria, mixed candidate runs and verdicts without evidence are rejected. Do not
let the candidate grade itself. Judge baseline and updated runs blind with the
same rubric, include the negative controls, and inspect disagreements manually.
Report per-case regressions as well as the total. These are development cases
derived from the same history as the instructions; use new held-out incidents
before claiming general improvement.

## Reproduce the history scan

```sh
node scan.mjs /home/hugob/.t3/userdata /tmp/reliability-history AUDIT_THREAD_ID
```

Use the current audit thread ID for exclusion. The scanner opens databases in
read-only mode and queries only thread/timeline/activity projections. It emits
inventory, terminal failure ledger, candidate signals and counts. It exports short
redacted diagnostics and payload hashes, not complete transcripts. Review exported
snippets before sharing; automated redaction cannot guarantee removal of every
possible secret. Task duplicates remain explicitly annotated. Re-running against
live history can change counts; the dated snapshot in this directory is the audit
evidence, not a promise of stable future totals.

## Verification performed

The dataset validation and rubric aggregation controls ran successfully. Controls
check all-pass versus one-failure aggregation and reject missing, duplicate and
empty-evidence verdicts. The policy's Nix integration was syntax-parsed. The existing
instruction installer was exercised on temporary files for repeat installation,
preference preservation and file permissions. Source references and policy copies
were checked against the retained records. The audit invoked no live model benchmark,
host rebuild, system activation, browser test, commit or push. Passing tooling
checks does **not** establish that any model passes these scenarios or that the new
instructions have improved its behavior.

During verification, the seminar repository's existing autosave workflow committed
its tracked edits, including the AGENTS addition, in `de40317`. The audit did not
invoke that commit or change the autosave setup. The new Yomi policy source is
staged specifically so Git-backed flake evaluation can see the referenced file;
at audit completion the remaining Yomi work was present as local changes/new files.

The final unrestricted `git diff --check` encountered concurrent changes in
`home/features/neovim/writing.nix` with spaces before tabs. That file was clean at
the start of this audit and was not edited by it. Checks scoped to the audit's
instruction/source files passed; the concurrent Neovim change was left intact.
The optional chart preview could not render because T3's browser libraries are
missing on the host. The chart was delivered through `html_render`; no host
packages were installed and no browser-validation claim is made.

On the unsigned-commit follow-up, the user explicitly authorized unsigned commits.
The amaterasu working-tree dry-build completed successfully, with existing Nix
cache-trust and unpinned SSH host-key warnings. It included concurrent Neovim
edits; those edits are excluded from the audit commit. No system was activated.
