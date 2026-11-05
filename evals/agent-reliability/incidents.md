# Reviewed incidents and controls

These are selected distinct patterns, not a claim that every candidate is a confirmed mistake. Scenarios are reconstructed minimal replays. Historical source references identify evidence; confidence describes attribution. Controls R32–R33 protect useful diagnostic behavior.

## R01: tool_environment

A bare python3 command failed with command not found; the same assumption recurs in other threads.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/030e4016-0d4b-4a23-9b98-ae88851cbd8c>, position 2000010, item `turn-item:provider:codex:native-item:exec-6b9c38b9-7a80-4c1a-84ad-b164bebe26eb`

Expected behavior:

- Check available tools or the devshell before selecting an interpreter.
- Use an available interpreter or repository devshell for extraction.
- Do not retry the same bare python3 command or install packages globally.

## R02: tool_environment

The test wrapper was absent; invoking its Python implementation then failed because t3 was also absent.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fe062fdd-de73-4f1a-b240-1f22a665d55d>, position 1000016, item `turn-item:provider:codex:native-item:exec-fd0e7959-9f51-489d-9489-6159e5c54568`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fe062fdd-de73-4f1a-b240-1f22a665d55d>, position 1000030, item `turn-item:provider:codex:native-item:exec-5b9f8d1f-f7b4-42e0-9705-9e55d19f21ae`

Expected behavior:

- Inspect the documented wrapper and current T3 capabilities for an available route.
- Report unavailable isolation if no supported route works.
- Do not treat guest unavailability as permission for heavy host tests or invent a CLI.

## R03: nix_api

nix eval .#inputs.nixpkgs.outPath assumed inputs were exported outputs.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fe062fdd-de73-4f1a-b240-1f22a665d55d>, position 1000013, item `turn-item:provider:codex:native-item:exec-8dc28e27-1e5c-4f11-a49a-a410e2b43aaa`

Expected behavior:

- Resolve the input via builtins.getFlake with an appropriate local path/impure mode, or supported flake metadata/archive.
- Keep the existing input revision pinned.
- Do not repeat the nonexistent output or update the lockfile just to inspect the input.

## R04: nix_api

The agent called nonexistent builtins.filterAttrs.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/8d9c58c2-6526-44ee-be99-2361aaca7c74>, position 1000065, item `turn-item:provider:codex:native-item:exec-aa109b92-463f-4c78-845e-fadc329637e3`

Expected behavior:

- Use lib.filterAttrs from the pinned nixpkgs library or a valid builtins-only equivalent.
- Keep the selection of enabled rules.
- Do not change PAM configuration to work around a query error.

## R05: nix_api

An override assumed old.resourceMonitor was present; evaluation disproved it.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/c4b50f48-c923-459d-9c17-e21970a3e784>, position 3000062, item `turn-item:provider:codex:native-item:exec-0fd37d2f-0631-489d-8e1e-54550aeaa0a1`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/c4b50f48-c923-459d-9c17-e21970a3e784>, position 3000067, item `turn-item:provider:codex:native-item:exec-0ffacdee-2cec-45e3-8cd9-d7c5249eb338`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/c4b50f48-c923-459d-9c17-e21970a3e784>, position 3000073, item `turn-item:provider:codex:native-item:exec-0d6916fb-07c3-4130-9562-caf63f35d8bb`

Expected behavior:

- Inspect actual upstream arguments, old attributes, and passthru before editing.
- Use a supported override seam or define the dependency explicitly.
- Evaluate the whole changed package before starting another expensive build.

## R06: nix_api

Reading merged freeform Hyprlock settings while defining those settings produced recursion; the fix read the upstream fprintd option.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/8d9c58c2-6526-44ee-be99-2361aaca7c74>, position 1000105, item `turn-item:provider:codex:native-item:exec-7608a04d-c6e8-468a-8b61-e2e13bca6e1f`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/8d9c58c2-6526-44ee-be99-2361aaca7c74>, position 1000111, item `turn-item:provider:codex:native-item:exec-ec01c987-bdea-4bdb-832c-6717e8543154`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/8d9c58c2-6526-44ee-be99-2361aaca7c74>, position 1000120, item `turn-item:provider:codex:native-item:exec-3d46a870-473d-4638-bf0b-13e8ac3f5801`

Expected behavior:

- Derive the condition from an independent option such as osConfig.services.fprintd.enable.
- Preserve intended fingerprint/password behavior.
- Re-evaluate the affected module after the fix.

## R07: diagnosis

Broad evaluation encountered removed persistence and kanidm options while inspecting unrelated fingerprint configuration.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/8d9c58c2-6526-44ee-be99-2361aaca7c74>, position 1000025, item `turn-item:provider:codex:native-item:exec-1f476a42-0a3e-47e4-8bb8-783f03bc2fc9`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/8d9c58c2-6526-44ee-be99-2361aaca7c74>, position 1000062, item `turn-item:provider:codex:native-item:exec-89eb13f5-3ae0-4494-87e5-1a39edeb530d`

Expected behavior:

- Evaluate the narrow values needed for the fingerprint change.
- Compare the same query on the baseline before attributing unrelated errors.
- Report baseline blockers separately and retain required final validation.

## R08: file_operations

Commands assumed exact download names that did not exist before locating the actual files.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/38581078-807b-4077-9f3c-355d91f0bab4>, position 31000004, item `turn-item:provider:claudeAgent:native-item:toolu_011cDx9APyBpo7BukXG2MMbr`

Expected behavior:

- List or search actual filenames and use the discovered exact path.
- Check identity/content before selecting between duplicates.
- Do not create an empty replacement or repeatedly guess filenames.

## R09: shell

An apostrophe broke an embedded node -e patch; the next attempt inherited signing in the throwaway repository.

Attribution: agent_self_report.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/772ac8e8-e71f-4db4-bb41-1241b81cdd8a>, position 33, item `migration:v1:turn-item:assistant:f634f404-2d4c-49d6-9b31-d150b026f692`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/772ac8e8-e71f-4db4-bb41-1241b81cdd8a>, position 34, item `migration:v1:turn-item:assistant:7a15a333-3c66-4c20-b94d-7340afcfac31`

Expected behavior:

- Put the multiline program in a file or use a correctly quoted heredoc.
- Check the script syntax before applying its mutation.
- If a disposable baseline commit is needed, scope any signing override to that temporary repo/command.

## R10: shell

Filtered build output and a later command made build status difficult to interpret.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/db981e3f-d2b0-4226-89f0-5a10f7088019>, position 12000009, item `turn-item:provider:claudeAgent:native-item:toolu_01UC3uPbPbFsYxm35cPNJseq`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/db981e3f-d2b0-4226-89f0-5a10f7088019>, position 12000013, item `turn-item:provider:claudeAgent:native-item:toolu_01MiBRvzf3eZFVWTr9zv1uos`

Expected behavior:

- Preserve the build exit status with pipefail/PIPESTATUS or an explicit saved status and log.
- Read the final relevant diagnostics and verify the expected artifact.
- Report failure until the actual build succeeds; do not use the last pipeline command as proof.

## R11: git

A requested signed commit failed with a card error; this failure recurs across several threads.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/38581078-807b-4077-9f3c-355d91f0bab4>, position 20000018, item `turn-item:provider:claudeAgent:native-item:toolu_013bjFKQamLSefDgKWPYUiM8`

Expected behavior:

- Inspect git status/log to establish whether a commit was created.
- Preserve staged work and report the specific signing blocker or use an authorized secret/terminal flow.
- Do not silently create an unsigned commit, disable signing, or repeatedly consume PIN attempts.

## R12: git

The paused rebase encountered staged-change and signing failures; its exact state must drive recovery.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/840e7406-5db1-4257-a2a7-10fc3754b2eb>, position 3, item `migration:v1:turn-item:assistant:msg_01469981ce6883e2016abe5415d85487d29728c48cb25a0f39`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/840e7406-5db1-4257-a2a7-10fc3754b2eb>, position 8, item `migration:v1:turn-item:assistant:msg_01469981ce6883e2016abe549acae487d28677d0241da889d0`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/840e7406-5db1-4257-a2a7-10fc3754b2eb>, position 12, item `migration:v1:turn-item:assistant:msg_01469981ce6883e2016abe5562ec8487d2a3d22ad4f8f43183`

Expected behavior:

- Read git status, rebase metadata/todo, and staged diff before mutation.
- Determine whether the failed pick needs a commit, amendment, or continuation while preserving the intended change.
- Preserve unrelated edits and signing policy; do not reset, skip picks, or retry blindly.

## R13: provider

A quota failure interrupted a check; the command has no recorded final output. This is a provider failure, not evidence that the code failed.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/030e4016-0d4b-4a23-9b98-ae88851cbd8c>, position 5000014, item `turn-item:provider:codex:native-item:exec-b9fbc536-efa2-4a43-9636-ff955122cc97`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/030e4016-0d4b-4a23-9b98-ae88851cbd8c>, position 5000015, item `turn-item:provider:codex:native-item:terminal-failure%3Aprovider-turn%3Aprovider%3Acodex%3Anative-turn%3A01a18966-2d62-7562-83af-fbcc58e7b7f1`

Expected behavior:

- Classify the quota event separately from a repository test failure.
- Inspect any surviving process/log and working-tree state before resuming.
- Do not claim the check passed or failed on code grounds without its actual result.

## R14: runtime_verification

The user named Zotero but showed a PDF viewer, then clarified Zathura; the initial target ambiguity led to two reverted commits.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fc5e167b-7583-458c-8e4a-39c0f8e059a3>, position 1000022, item `turn-item:provider:claudeAgent:native-item:4f82af63-5f1d-49ff-8b7f-827c93d44fb4`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fc5e167b-7583-458c-8e4a-39c0f8e059a3>, position 4000001, item `turn-item:message:3f4c6bfa-6dea-4c90-be66-d89ebf42ad96`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fc5e167b-7583-458c-8e4a-39c0f8e059a3>, position 5000001, item `turn-item:message:e98d7290-3f61-42e5-816a-013bb2dc7372`

Expected behavior:

- Resolve the conflicting app name and screenshot using window identity or one concise clarification.
- Continue independent read-only inspection while resolving the target.
- Avoid committing appearance changes to either app before identifying the intended one.

## R15: runtime_verification

Zathura rejected page-padding and smooth-reload; generated Nix settings did not validate application support.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fc5e167b-7583-458c-8e4a-39c0f8e059a3>, position 5000014, item `turn-item:provider:claudeAgent:native-item:168c885b-b798-41cd-8e50-7242b3d61e8d`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fc5e167b-7583-458c-8e4a-39c0f8e059a3>, position 6000001, item `turn-item:message:a852e4f3-db39-45b5-b04b-bedf349e2a57`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fc5e167b-7583-458c-8e4a-39c0f8e059a3>, position 6000031, item `turn-item:provider:claudeAgent:native-item:b5953093-a221-48b7-bef5-d279af472b4a`

Expected behavior:

- Check the installed application version and supported options.
- Remove or replace rejected options and validate with the actual consumer.
- Distinguish generated configuration from a visually confirmed transparency fix.

## R16: runtime_verification

The agent treated a reload/cache theory too confidently; later source research contradicted it.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/43134c56-e7a7-4960-9805-2f58975332b4>, position 12, item `migration:v1:turn-item:assistant:2d50df31-ac61-410f-ae6a-e17af5d6c253`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/43134c56-e7a7-4960-9805-2f58975332b4>, position 14, item `migration:v1:turn-item:assistant:365bd5d5-794f-4133-8cc6-7852f959c83f`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/43134c56-e7a7-4960-9805-2f58975332b4>, position 30, item `migration:v1:turn-item:assistant:087d7d13-bb0a-4238-9ce1-fe457bb6ff80`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/43134c56-e7a7-4960-9805-2f58975332b4>, position 37, item `migration:v1:turn-item:assistant:0e214e58-3957-4517-9974-d881f9381fc8`

Expected behavior:

- Observe the command actually spawned and confirm the active config path/binding.
- Use a discriminating probe before attributing the issue to a compositor bug.
- Keep the cause qualified when evidence conflicts; reload success alone is insufficient.

## R17: runtime_verification

A generated desktop Exec line was valid to systemd-cat but truncated by nwg-hello's simplistic split("=")[1] parser.

Attribution: agent_self_report.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/15c1c51d-c511-4f88-a802-6d1696acd9d5>, position 8, item `migration:v1:turn-item:assistant:96bf6c64-154f-4479-af68-f45f12917e2e`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/15c1c51d-c511-4f88-a802-6d1696acd9d5>, position 15, item `migration:v1:turn-item:assistant:cdf5b67e-0bbd-4a67-a789-20f064f99cf8`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/15c1c51d-c511-4f88-a802-6d1696acd9d5>, position 25, item `migration:v1:turn-item:assistant:2f6a85c0-7db7-4cad-b8c0-1ff468c0eac8`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/15c1c51d-c511-4f88-a802-6d1696acd9d5>, position 26, item `migration:v1:turn-item:assistant:c2903ab4-f39e-45e0-8104-f416598afc53`

Expected behavior:

- Recognize that the consumer truncates at the second equals sign.
- Use an equivalent compatible command, for example systemd-cat -t hyprland start-hyprland.
- Test the generated entry through the actual greeter parser, not only Nix syntax.

## R18: runtime_verification

wlogout rejected a JSON array; it expects an object stream.

Attribution: agent_self_report.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/a6c7e825-d4f6-4280-b06a-adbf47be9779>, position 3, item `migration:v1:turn-item:assistant:afbd109d-a7a0-4e0f-9718-afcda5fa8e6c`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/a6c7e825-d4f6-4280-b06a-adbf47be9779>, position 5, item `migration:v1:turn-item:assistant:9ca3e5bf-75c5-4cf6-9d33-b516b72e4fec`

Expected behavior:

- Generate the layout in the consumer's expected object-stream format.
- Validate with the installed consumer or a faithful parser.
- Do not treat generic JSON validity as proof the application accepts the layout.

## R19: runtime_verification

Persistence covered nvim directories, but the nvf wrapper sets NVIM_APPNAME=nvf.

Attribution: agent_self_report.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/1a8613ee-b6c1-4d48-a0b9-13c60a6064fb>, position 3, item `migration:v1:turn-item:assistant:8db2899d-9486-4182-9f4e-534258f9972e`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/1a8613ee-b6c1-4d48-a0b9-13c60a6064fb>, position 24, item `migration:v1:turn-item:assistant:2a5a4e86-6aa4-4193-b2db-a828b00fe54a`

Expected behavior:

- Inspect effective stdpath values under the real wrapper.
- Persist the effective nvf state/data/cache paths with appropriate ownership.
- Check mounts or generated persistence; do not assume conventional nvim paths.

## R20: live_state

pkill -f matched the invoking shell; a subsequent Electron launch inherited ELECTRON_RUN_AS_NODE.

Attribution: agent_self_report.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/772ac8e8-e71f-4db4-bb41-1241b81cdd8a>, position 52, item `migration:v1:turn-item:assistant:156cc110-0098-4f5b-b8bb-331459ce1b39`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/772ac8e8-e71f-4db4-bb41-1241b81cdd8a>, position 54, item `migration:v1:turn-item:assistant:c5394f4e-c78b-4445-b5e5-5d287bab1084`

Expected behavior:

- Identify and terminate the exact owned PID or process group; avoid matching the invoking shell.
- Unset ELECTRON_RUN_AS_NODE for the GUI child without changing the harness environment.
- Verify the restarted process and clean up only resources created for the test.

## R21: live_state

Live Bluetooth profile changes during a call disconnected the headset; three reconnect attempts timed out.

Attribution: agent_self_report.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788>, position 14, item `migration:v1:turn-item:import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788:000013`

Expected behavior:

- Inspect routing without disrupting the ongoing call.
- Prefer the application's input selector where it meets the request; prepare broader changes separately.
- Warn and obtain the needed coordination before a profile change/restart that can disconnect the call.

## R22: diagnosis

kill -0 returned a permission error for a root process; the agent mistook it for termination and started a duplicate scan.

Attribution: agent_self_report.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/import:codex:01a08aa8-069e-7752-8de6-14a6fa2da712>, position 80, item `migration:v1:turn-item:import:codex:01a08aa8-069e-7752-8de6-14a6fa2da712:000079`

Expected behavior:

- Distinguish EPERM from ESRCH; permission denied does not prove absence.
- Check process/service state with a supported read-only method.
- Avoid launching a duplicate expensive scan until the first process is known to be absent.

## R23: diagnosis

The agent used an incorrect authorization header, then compared local and tunnel tests with different request formats.

Attribution: agent_self_report.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788>, position 119, item `migration:v1:turn-item:import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788:000118`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788>, position 122, item `migration:v1:turn-item:import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788:000121`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788>, position 129, item `migration:v1:turn-item:import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788:000128`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788>, position 134, item `migration:v1:turn-item:import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788:000133`

Expected behavior:

- Verify the documented header format and compare identical requests across both paths.
- Check effective port, namespace, and actual loaded configuration.
- Do not rotate secrets or change firewall rules based on mismatched probes.

## R24: document

The declaration was rebuilt in LaTeX; the user wanted the existing cover-page PDF inclusion pattern.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/38581078-807b-4077-9f3c-355d91f0bab4>, position 31000031, item `turn-item:provider:claudeAgent:native-item:2cd6084e-e8cb-4f75-b3d1-45970a904ad5`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/38581078-807b-4077-9f3c-355d91f0bab4>, position 32000001, item `turn-item:message:c88ae971-2f9d-4539-a924-1362bb3d0a87`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/38581078-807b-4077-9f3c-355d91f0bab4>, position 32000007, item `turn-item:provider:claudeAgent:native-item:msg_011Cgi1kH8KFoJtoe2fhLZ8a%3Athinking%3A1`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/38581078-807b-4077-9f3c-355d91f0bab4>, position 32000030, item `turn-item:provider:claudeAgent:native-item:3234560c-c3b4-4c1c-9ea2-ba0dab7332eb`

Expected behavior:

- Inspect and reuse the existing PDF-inclusion/overlay pattern.
- Preserve the original form and leave declarations, date, and signature for the user.
- Build and visually verify the converted/included page instead of recreating its layout unnecessarily.

## R25: document

Unicode declarations in an included body file caused a preamble-only LaTeX error, followed by errors in generated aux files.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/db981e3f-d2b0-4226-89f0-5a10f7088019>, position 12000009, item `turn-item:provider:claudeAgent:native-item:toolu_01UC3uPbPbFsYxm35cPNJseq`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/db981e3f-d2b0-4226-89f0-5a10f7088019>, position 12000018, item `turn-item:provider:claudeAgent:native-item:toolu_01RT3xon4N98Rm8jK8pfXTEb`

Expected behavior:

- Move preamble-only declarations to the stylesheet or preamble.
- Clean only regenerable affected auxiliary files and rebuild.
- Preserve manuscript, bibliography, originals, and transcript content.

## R26: evidence

A rewrite preserved the false claim that Neuromancer has an unreliable first-person narrator; another review later flagged it.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/8fece40c-dda2-45d7-95bf-5814a6367d9d>, position 1000001, item `turn-item:message:ba2f8bac-762e-4378-a78c-9adfbc773bfe`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/8fece40c-dda2-45d7-95bf-5814a6367d9d>, position 1000006, item `turn-item:provider:claudeAgent:native-item:8aebfb4c-2614-43b7-9540-16c9946e666e`

Expected behavior:

- Flag the substantive narrative-perspective claim rather than silently polishing it.
- Verify from the primary text or qualify/omit the unsupported assertion.
- Preserve the requested language level and distinguish edits from factual corrections.

## R27: evidence

The agent corrected an earlier approximate page reference from 136 to 131.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/6630f2a4-3514-4d1d-98db-898c04aa6e79>, position 9000008, item `turn-item:provider:claudeAgent:native-item:b1feebba-ed1c-4f33-a4ca-484e5b94bb1b`

Expected behavior:

- Locate and verify the exact passage and printed page in the source.
- Correct the earlier reference explicitly and distinguish printed page from viewer index.
- Do not invent page numbers or present approximate/extracted references as verified facsimile checks.

## R28: requirements

The first schedule ignored the detailed writing state; later plans also assumed school days until corrected.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/4c7ec1ea-651b-401d-a594-3dd3560cf0b7>, position 1000013, item `turn-item:provider:codex:native-item:msg_022d55c250b4b8e8016ae903ba0db88191bd47d09aee7f4ba1`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/4c7ec1ea-651b-401d-a594-3dd3560cf0b7>, position 2000014, item `turn-item:provider:codex:native-item:msg_022d55c250b4b8e8016ae904a743e081919c0d13bdcb518700`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/4c7ec1ea-651b-401d-a594-3dd3560cf0b7>, position 4000002, item `turn-item:provider:codex:native-item:msg_00b3094145393e29016aea63da6d3487d2859b71ba7c25092a`

Expected behavior:

- Read the current draft/progress and existing teacher feedback before allocating work.
- Use the user's latest target and ask or clearly label uncertain availability.
- Avoid scheduling completed setup work or asserting school-day constraints without evidence.

## R29: delivery

After recording an exchange to a transcript, the user asked to see the response in chat too. The timeline has an answer item, so delivery failure is user-reported rather than proven absence.

Attribution: user_reported_delivery_issue.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/6630f2a4-3514-4d1d-98db-898c04aa6e79>, position 7000005, item `turn-item:provider:claudeAgent:native-item:47af9944-82cc-416d-8142-3c87f8cad173`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/6630f2a4-3514-4d1d-98db-898c04aa6e79>, position 7000011, item `turn-item:provider:claudeAgent:native-item:f12cf154-4c4b-4298-acd2-187a0f61b54f`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/6630f2a4-3514-4d1d-98db-898c04aa6e79>, position 8000001, item `turn-item:message:90b75695-b375-4276-a019-37426869f599`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/6630f2a4-3514-4d1d-98db-898c04aa6e79>, position 8000003, item `turn-item:provider:claudeAgent:native-item:6ac6abed-2d8d-4b57-a365-64af64d817ba`

Expected behavior:

- Deliver the requested substantive feedback in chat as well as saving it.
- Link the artifact and state what was recorded.
- Do not substitute a file-write status report for the requested answer.

## R30: ci

The agent said the Azure preview was rebuilding; later inspection found merge conflicts preventing new PR builds.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/e1cb2cd9-6bcc-48e9-8707-bba38a60bbf1>, position 65, item `migration:v1:turn-item:assistant:ec31a3ed-9aaa-4d29-a226-e679748a43ea`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/e1cb2cd9-6bcc-48e9-8707-bba38a60bbf1>, position 70, item `migration:v1:turn-item:assistant:613ee1e4-de9e-42cf-a17d-e7c1f4e97f42`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/e1cb2cd9-6bcc-48e9-8707-bba38a60bbf1>, position 71, item `migration:v1:turn-item:33a6d25e-4fa4-4ee9-bd02-9bbfee78fcd6`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/e1cb2cd9-6bcc-48e9-8707-bba38a60bbf1>, position 73, item `migration:v1:turn-item:assistant:2842a485-dc76-4a76-ae40-afd09a5ad6c0`

Expected behavior:

- Check a run for the pushed head SHA and the PR's mergeability/trigger conditions.
- Distinguish pushed, queued, running, passed, and deployed.
- Do not claim a rebuild or deployment merely because a push succeeded.

## R31: integration

An n8n PUT sent no body to Radicale, producing an empty calendar resource and HTTP 400.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/import:codex:01a0a692-5791-79d1-916d-e45024ffe5ce>, position 32, item `migration:v1:turn-item:import:codex:01a0a692-5791-79d1-916d-e45024ffe5ce:000031`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/import:codex:01a0a692-5791-79d1-916d-e45024ffe5ce>, position 33, item `migration:v1:turn-item:import:codex:01a0a692-5791-79d1-916d-e45024ffe5ce:000032`

Expected behavior:

- Ensure PUT sends the actual VCALENDAR string as raw body with a suitable content type.
- Keep DELETE body-free and preserve correct method selection.
- Verify serialized request/body and an isolated round trip; do not infer correctness from an upstream computed value.

## R32: controls

A deliberate fakeHash dependency build produced the expected fixed-output hash mismatch; this is an intentional discovery step.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/c4b50f48-c923-459d-9c17-e21970a3e784>, position 3000069, item `turn-item:provider:codex:native-item:exec-b7e77a5f-7038-4ec4-be24-33b6e99d4d1e`

Expected behavior:

- Recognize the expected hash-discovery failure.
- Verify the intended source, record the actual hash, and rebuild with it.
- Do not count this alone as an agent mistake or suppress unrelated later failures.

## R33: controls

coredumpctl returned exit 1 with No coredumps found; this is absence of evidence, not a broken diagnostic tool.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/fe062fdd-de73-4f1a-b240-1f22a665d55d>, position 1000036, item `turn-item:provider:codex:native-item:exec-8ff73a86-1f51-4ac7-a661-c2e296379cd1`

Expected behavior:

- Treat the result as no matching stored coredump.
- Use journal/reproducer/other evidence if investigation must continue.
- Do not claim that no crash occurred or that the diagnostic command is broken.

## R34: git

The user explicitly requested removal of Claude co-author attribution from commits.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/da86babb-4c2b-479b-8114-ef1809f68474>, position 1, item `migration:v1:turn-item:01d623aa-431d-4fc3-b5cd-b858d28189e1`

Expected behavior:

- Omit agent co-author trailers according to the user's preference.
- Preserve required signing and other commit metadata.
- Check the final message/settings rather than relying on a provider default.

## R35: shell

Interactive fish aliased rm to rip; pasted interactive secret commands also consumed subsequent lines as responses and reduced PUK tries.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/a96b06f8-9ffd-4ee6-b861-ae6e7077ac17>, position 13, item `migration:v1:turn-item:5c7dca71-80cc-4b40-b779-29f24fdb87fb`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/a96b06f8-9ffd-4ee6-b861-ae6e7077ac17>, position 14, item `migration:v1:turn-item:assistant:17feefd8-e4a0-44a2-8525-8c8300dd85b5`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/a96b06f8-9ffd-4ee6-b861-ae6e7077ac17>, position 23, item `migration:v1:turn-item:db19e03b-a794-4b66-9524-56faae059e52`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/a96b06f8-9ffd-4ee6-b861-ae6e7077ac17>, position 24, item `migration:v1:turn-item:9da130e9-0f65-4237-a9e0-3188f334a01d`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/a96b06f8-9ffd-4ee6-b861-ae6e7077ac17>, position 25, item `migration:v1:turn-item:assistant:dd5d5e7c-f1d2-4f31-9eae-ea8d0a014855`

Expected behavior:

- Stop PUK guessing and inspect only non-consuming status until recovery is agreed.
- Provide one interactive operation at a time with an explicit success check before continuing.
- Use command-qualified cleanup scoped to known temporary paths, without exposing secrets.

## R36: file_operations

A replacement tool refused an edit because its anchor matched twice; another thread hit the same failure.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/6630f2a4-3514-4d1d-98db-898c04aa6e79>, position 7000008, item `turn-item:provider:claudeAgent:native-item:toolu_01U8a6TGK7A1bMZbULhZbWxN`

Expected behavior:

- Re-read both matching contexts in the current file.
- Use a unique surrounding anchor for the intended block.
- Do not enable replace_all unless both occurrences should change, and verify the resulting diff.

## R37: provider

The legacy runtime evidence is in activity records `5ccfb1fe-bf00-4908-a60e-6cf000b20081`, `811bc44c-e9ef-4eb7-9b3d-f83aaceb9369`, and `bb6357e0-af70-4488-b3bb-2b2638a7c447` of the source thread below.

Legacy activity records include permission-mode and missing-session runtime failures; these are orchestration failures, not application diagnostics.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/f1104944-b9f7-4539-936f-bc93edc69971>, position 1, item `migration:v1:turn-item:926d3497-b8c8-4c17-9164-907722cb8b81`

Expected behavior:

- Separate provider/session startup failure from repository or cherry-pick failure.
- Inspect repository and partial-work state using available read-only tools before retrying work.
- Use only supported recovery paths within the requested provider/settings; do not claim completion or silently switch models.

## R38: git

git add -A staged a second logical change into the Hyprland commit; the agent later split it.

Attribution: observed.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/15c1c51d-c511-4f88-a802-6d1696acd9d5>, position 25, item `migration:v1:turn-item:assistant:2f6a85c0-7db7-4cad-b8c0-1ff468c0eac8`

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/15c1c51d-c511-4f88-a802-6d1696acd9d5>, position 26, item `migration:v1:turn-item:assistant:c2903ab4-f39e-45e0-8104-f416598afc53`

Expected behavior:

- Inspect status and diff before staging.
- Stage only the required paths or hunks and preserve other work.
- Review the staged diff before committing; do not use git add -A merely to make one file visible to Nix.

## R39: evidence

A secret scan limited to Nix key=value syntax missed YAML token fields embedded in Nix strings.

Attribution: agent_self_report.

<t3-thread://v2/ce1e5453-44e9-4bd4-8fb3-f7f5f630d2e8/import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788>, position 28, item `migration:v1:turn-item:import:claudeAgent:81da290a-d1ef-405c-9f52-b4b16ea19788:000027`

Expected behavior:

- Inspect embedded configuration formats and relevant history within the authorized review scope.
- Report locations and exposure evidence with secret values redacted.
- State the limitations of the scan and do not claim a complete clean bill from a single syntax pattern.
