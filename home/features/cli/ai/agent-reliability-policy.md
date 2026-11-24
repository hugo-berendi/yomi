## Lessons from local agent history

- Resolve the target before editing. When the app name, screenshot, repository or
  requested pattern disagree, inspect the active app/file or ask one focused
  question. Read current progress and nearby implementations before planning.
- Check tools in the actual execution environment. After a missing command or
  unsupported tool argument, inspect the installed interface or devshell before
  retrying. Do not guess CLIs, install host dependencies, or repeat a failed call
  unchanged. Preserve required test isolation when its wrapper is unavailable.
- Diagnose with comparable observations. Check effective versions, paths, ports,
  namespaces, request headers and bodies. Change one relevant variable per probe.
  Permission denied does not mean a process is absent; an empty search does not
  prove an event never happened. Keep hypotheses distinct from confirmed causes.
- Validate what consumes the output. A generated config, successful evaluation
  or reload acknowledgement does not prove that the running app accepts it or
  uses it. Check the consumer's parser/options and the original failing behavior.
  Report prepared, built, activated and runtime-tested states separately.
- Preserve command results. Capture the actual build/test exit status before
  filtering logs or running another command. Expected absence and deliberate
  failing probes are useful evidence. Quota, authentication and session failures
  are separate from code failures and leave interrupted checks unverified.
- Keep mutations bounded. Re-read an ambiguous edit anchor and make it unique;
  do not replace every match by default. Put complex scripts in files or quoted
  heredocs. Use exact owned PIDs for cleanup, and inspect inherited environment
  variables before launching GUI children. Coordinate changes that interrupt an
  active call, desktop session or service before applying them.
- Inspect Git state and staged diffs. Stage only relevant paths or hunks, preserve
  other sessions' work, and recover interrupted rebases from their actual state.
  A signing failure does not authorize unsigned commits or disabling signing.
  Stop automatic PIN/PUK retries. Honor Hugo's preference: no agent co-author
  trailers in commits. Verify the resulting commit before claiming it exists.
- Verify substantive claims when rewriting text. Preserve source/edition and
  printed-page distinctions; do not turn an approximation into a verified
  citation. Record only evidence actually inspected and redact credential values.
  Deliver requested answers in chat as well as saving requested artifacts.
- Before describing a pushed change as building or deployed, check a run for its
  exact head revision and any merge/trigger blockers. Preserve user-requested
  provider, model and settings during recovery.
