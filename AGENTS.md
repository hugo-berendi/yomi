# Agent guide for Yomi

One flake configures six machines: role profiles, the pilot's home
configuration, per-host services, sops-nix secrets and impermanence. This file is the map and
the rules. Each area has its own `AGENTS.md` with the details: read the one for
the area you change before you edit it.

## Orient first

```bash
hostname                  # who am I
git status -sb            # other machines push here; rebase before starting
git log --oneline -10     # what landed since last time
```

- You are often running *on* `inari`, the home server and router. There
  `just nixos-rebuild switch` rebuilds the machine you are living inside,
  `journalctl` shows the real services, and a mistake takes down the thing you
  are talking through.
- `hostname` decides whether `just nixos-rebuild <action> <host>` acts locally
  or over SSH, and which host's services you can inspect directly.
- Several machines commit here, sometimes during a session. Expect to rebase,
  and read what arrived: it may already do what you were about to do.

## Where things live

| You want to … | Go to | Read first |
|---|---|---|
| add or change a service on inari | `hosts/nixos/inari/services/<name>.nix` or `<name>/` | `hosts/nixos/inari/services/AGENTS.md` |
| change inari's network, disks or how it runs | `hosts/nixos/inari/` | `hosts/nixos/inari/AGENTS.md` |
| change what every host, or every host of a kind, gets | `profiles/` | `profiles/AGENTS.md` |
| change a program or desktop piece the pilot uses | `home/features/` | `home/AGENTS.md` |
| change what agents are told, their models or skill links | `home/features/cli/ai/instructions/*.md`, `instructions.nix`, `skills.nix`; skills themselves live in `~/projects/ai-skills` | `just ai-explain` |
| define or change a `yomi.*` option | `modules/` | `modules/AGENTS.md` |
| change one machine's hardware, disks or own settings | `hosts/nixos/<host>/` (`home.nix` for its Home Manager settings) | |
| package something | `pkgs/` | |
| pin a container image | `hosts/nixos/inari/images.nix` (CI bumps the digests) | |
| record another host's address or SSH alias | `profiles/inventory.nix` | |
| look up an option | `docs/options.md` (generated) or `just where <option>` | |
| understand how the options fit together | `docs/concepts.md` | |

`common/` and `modules/common/` hold what both NixOS and Home Manager load.
Documentation about one service sits beside it as `README.md`; `docs/` holds
the rest.

## Hosts

| Host | Role | Profile |
|------|------|---------|
| `amaterasu` | Framework 13 laptop: Btrfs, impermanence, Hyprland | `profiles/desktop.nix` |
| `inari` | Home server and router: ZFS, impermanence, ~50 services, Docker, nftables and dnsmasq | `profiles/server.nix` |
| `ebisu` | VPS running the Pangolin gateway | `profiles/vps.nix` |
| `tsukuyomi` | Home PC, NixOS-WSL on Windows; no impermanence | `profiles/wsl.nix` |
| `wsl-work` | Work laptop, NixOS-WSL; same profile as tsukuyomi | `profiles/wsl.nix` |
| `iso` | Installation and recovery image | `profiles/recovery.nix` |

## Commands

```bash
just nixos-rebuild build <host>     # build without applying
just nixos-rebuild dry-build <host> # quick evaluation check
just nixos-rebuild switch [<host>]  # apply; local when <host> is this machine
just lint                           # alejandra, stylua, statix, deadnix, ruff, shellcheck, shfmt
just fmt                            # format everything
just check-quick                    # option and persistence regression checks; run before pushing
just check                          # nix flake check --keep-going
just docs                           # regenerate docs/options.md after changing an option
just where <option> [host]          # every file that sets an option, and what it sets
just explain <service> [host]       # what a service brings: ports, endpoints, units, secrets, state
just ai-explain [host]              # what each agent harness gets: instruction blocks, skills, models
just ai-sync                        # rewrite this machine's agent instruction blocks without a switch
just new-service <name> [host]      # a new service file with a free port, staged
just parity [--base REV] [--new REV] [--host H]  # what changed in the built systems
just hardening-report <host>        # evaluated sandbox settings and their sources
just import-host-key <host>         # pin a host's real sshd key
just sops-rekey                     # rekey every secrets file
```

The `nixos-rebuild` recipe detects local versus remote, handles sudo and passes
`--no-reexec`. Run linters through `nix develop -c` when a tool is not on your
PATH: `shellcheck` exists only in the devshell, which is how CI runs it.

## Verify against what is built

Nix can tell you what the configuration produces, and the answer is repeatedly
not what the source seems to say. Ask it:

```bash
nix eval --json '.#nixosConfigurations.inari.config.services.restic.backups' --apply builtins.attrNames
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.inari.config.environment.etc."ssh/sshd_config".source'
just where yomi.web.at.mealie.port inari
just parity --host inari
```

Found this way after reading the source missed them: an sshd that still
accepted passwords after `PasswordAuthentication = false`; a systemd unit
conjured entirely out of hardening settings; a "relaxation" that tightened a
service; a container restarting on every commit.

Never measure with `grep` what you can measure with `nix eval`: counting files
that mention hardening reported 52 unhardened services, evaluating
`serviceConfig.ProtectSystem` showed 5. And `grep` sees neither `mkIf`
conditions nor values built in Nix; `just where` does.

`just parity` compares the derivation graphs of two revisions with store
hashes blanked out, because any edit changes the flake source hash and with it
every drvPath that embeds a `${./file}`. "Identical" means the built systems do
not differ; a list of derivations is exactly what a switch would change.

## Rules

1. `git add` a new file before evaluating: flakes see only tracked files. Stage
   specific paths; `git add -A` can capture another session's work.
2. A service keeps everything it needs in its own file: ports, endpoint, LAN
   grant, Pangolin resource, state, backups. Do not add to central lists.
3. Publish HTTP through `yomi.web.at`, and state `authentication` truthfully.
4. Secrets stay encrypted in `secrets.yaml`. A module used by several hosts
   takes a `sopsFile` option instead of a relative path.
5. Sandbox with native `systemd.services.<unit>.serviceConfig`; no presets.
   Check `just hardening-report` before adding settings.
6. A comment records why, with the evidence. When you change a value, re-read
   the comment above it. History belongs in the commit message; keep it in a
   comment only as a warning ("X does not work, because Y").
7. Verify with evaluation (`nix eval`, `just where`, `just explain`,
   `just parity`) and `just lint`, then dry-build the affected hosts.
8. Commit each logical change on its own and say what was verified and how.
   No agent co-author trailers; signing failures do not justify unsigned
   commits.
9. On a machine you are running inside, switching is the human's call. Say
   first which units will restart.
10. Do not create branches or worktrees unless asked.

## Gotchas

- **`nixConfig` must be a top-level flake attribute with literal values.**
  flake-parts' `flake.nixConfig` is ignored and a thunk is refused, so it
  cannot import `common/caches.nix`. Keep both lists in step.
- **`nixpkgs.config.allowUnfree` is a NixOS setting.** The flake's own package
  outputs get it from the explicitly instantiated `mkPkgs`.
- **List options merge by concatenation**, even two `mkForce` definitions.
  Resolve to one value in plain Nix first.
- **`./file` inside a flake belongs to the flake source**, whose hash changes
  with every commit. Mounting one into a container restarts it on every
  switch; use `builtins.path { path = ./file; name = "..."; }`.
- **`PasswordAuthentication = false` alone does not disable password login**:
  `KbdInteractiveAuthentication` and PAM bring the prompt back. Set both.
- **A nixpkgs bump can move a language runtime under a package.** karakeep
  0.32.0 dumped core on start once nodejs 24 arrived. When a service dies
  without an application error, compare the runtime across generations.
- `nix.package` is lix; Hyprland follows nixpkgs-unstable; stylix is pinned to
  release-26.05.

## CI

Forgejo Actions in `.forgejo/workflows/`:

- `check-nixos-flake.yml` on push and PR: `just lint`, `just check`, and
  builds of amaterasu, inari, tsukuyomi and wsl-work.
- `update-flake-inputs.yml`, daily 18:00 Berlin: `nix flake update` (all
  inputs Monday and Thursday, otherwise only `llm-agents` and `t3code-nix`)
  onto the rolling `update-flake-inputs` PR.
- `update-packages.yml`, daily 18:30 Berlin: `nix-update` for `pkgs/` and the
  image digests onto the rolling `update-packages` PR.

Update PRs merge themselves only when lint, check and the deterministic gate
(`scripts/ci/update-gate.py`: lock revisions, package versions and hashes,
image digests) agree, and only with the `UPDATE_BOT_TOKEN` secret.
`nix flake check` evaluates every package output, so a broken `pkgs/`
derivation fails CI even if no host uses it.

## Use the skills you were given

Read your harness's skill list at session start and invoke a matching skill
instead of hand-rolling its job.

| When | Invoke |
|------|--------|
| anything is broken, failing, crashing, hanging or slow | `diagnosing-bugs`, before forming a theory |
| reviewing a diff, or commits from another machine | `code-review` |
| before pushing changes to sops, ssh, firewall, hardening or backups | `security-review` |
| tidying up after a change lands | `simplify` |
| hooks, permissions, env vars, settings.json | `update-config` |
| Claude/Anthropic model ids, pricing, limits or the API | `claude-api`, never from memory |
| writing prose a human will read | `unslop` |

`gh-fix-ci` and `gh-address-comments` target GitHub, and this repo is on
Forgejo; `security-best-practices` does not cover Nix; `init` would replace
this file. Names differ between harnesses: match the list you were given.

## Lessons from earlier sessions

The cases and evidence are in `evals/agent-reliability/README.md`; the shared
policy is `home/features/cli/ai/instructions/reliability.md`.

- Use `nix develop -c just …` when `just` is not on PATH. Inspect a missing
  test wrapper's dependencies before retrying it. Keep heavy tests in the
  managed environment and report when it is unavailable.
- Flake inputs are not outputs: inspect them with `builtins.getFlake` or their
  metadata. `filterAttrs` is in `lib`, not `builtins`. Inspect real derivation
  attributes before overriding them.
- A successful evaluation does not prove the consumer accepts the result:
  check generated files with the program that reads them.
- Compare identical requests locally and through the proxy before changing
  credentials or networking. Check mounts when a persisted directory can hide
  generated configuration.
- For runtime diagnosis use exact owned PIDs, and account for inherited
  `ELECTRON_RUN_AS_NODE`. Do not disconnect a live call or close the user's
  windows as an incidental test. A permission error from `kill -0` does not
  mean the process exited.
