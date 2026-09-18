# Agent Guidelines for Yomi

Flake-based NixOS configuration managing 5 hosts with shared modules, home-manager, sops-nix secrets, and impermanence.

## Orient before doing anything

**Run `hostname` first.** It is one command and it changes almost everything that follows:

- **You are often running _on_ `inari`**, not on a workstation pointed at it. Then `just nixos-rebuild switch` is a local rebuild of the machine you are living inside, `journalctl` shows the real services, and a mistake takes down the thing you are talking through.
- It decides whether `just nixos-rebuild <action> <host>` goes local or remote — the recipe branches on `hostname`.
- It tells you which host's services you can inspect directly instead of guessing from source.

Then, before editing:

```bash
hostname                  # who am I
git status -sb            # other machines push to this repo; rebase before starting
git log --oneline -10     # what landed since last time
```

More than one machine commits here, sometimes during a session. Expect to rebase, and read what arrived — it may already have done what you were about to do, or half-done it.

## Hosts

| Host | Role | Notes |
|------|------|-------|
| `amaterasu` | Framework 13 laptop | BTRFS + impermanence, hyprland, desktop |
| `tsukuyomi` | Tower PC (dormant) | Runs Windows now; config kept but excluded from CI and `nix flake check` |
| `inari` | Home server | ZFS, ~40 services, Docker containers, router (nftables/hostapd/dnsmasq) |
| `iso` | Installation ISO | Bootable installer |
| `wsl` | WSL environment | No impermanence |

## Commands

```bash
just nixos-rebuild build <host>     # Dry-build (validates without applying)
just nixos-rebuild switch           # Apply locally (auto-detects hostname)
just nixos-rebuild switch <host>    # Apply remotely via SSH
just nixos-rebuild dry-build <host> # Quick eval check
just lint                           # alejandra + stylua + statix + deadnix + ruff + shellcheck/shfmt
just fmt                            # Format everything
just check                          # nix flake check --show-trace --keep-going
just import-host-key <host>         # Pin a host's real sshd key for knownHosts
just sops-rekey                     # Rekey every secrets file
```

**Always dry-build before committing.** The `nixos-rebuild` recipe is a Python wrapper that auto-detects local vs remote, handles sudo, and passes `--no-reexec` (nixos-rebuild-ng).

Every linter must be invoked through `nix develop -c`. `shellcheck` is in the devshell and on no profile, so a bare call only works from a shell that already entered it — which is not how CI runs.

## Verify against the built artifact, not the source

This is the single highest-value habit in this repo. Nix makes it cheap to ask what the configuration *actually produces*, and the answer is repeatedly not what the source appears to say.

```bash
# What a host really evaluates to
nix eval --raw '.#nixosConfigurations.inari.config.system.build.toplevel.drvPath'

# A specific option, after all merging
nix eval --json '.#nixosConfigurations.inari.config.services.restic.backups' --apply builtins.attrNames

# The generated file, not the option that feeds it
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.inari.config.environment.etc."ssh/sshd_config".source'

# Which units a switch will actually restart
cur=$(readlink -f /run/current-system); new=$(nix build --no-link --print-out-paths '.#nixosConfigurations.inari.config.system.build.toplevel')
for f in $(ls "$cur/etc/systemd/system" "$new/etc/systemd/system" | sort -u); do
  cmp -s "$cur/etc/systemd/system/$f" "$new/etc/systemd/system/$f" || echo "CHANGED $f"
done
```

Things found this way that source-reading missed: an sshd that still accepted passwords after `PasswordAuthentication = false`; a systemd unit conjured entirely out of hardening settings; a "relaxation" that tightened a service; a container restarting on every commit.

**Never measure with `grep` what you can measure with `nix eval`.** Counting files that mention `hardening` reported 52 unhardened services; evaluating `serviceConfig.ProtectSystem` showed the real number was 5, because upstream modules already harden most of them.

## CI

Forgejo Actions (`.forgejo/workflows/`):
- `check-nixos-flake.yml`: push/PR — `just lint`, `just check`, builds amaterasu + inari + wsl
- `update-flake-inputs.yml`: daily cron — `nix flake update`, builds hosts, auto-commits to main if checks pass
- `update-packages.yml`: weekly — `nix-update` for the `pkgs/` derivations

`nix flake check` covers amaterasu, inari, iso and wsl, and evaluates **every** package output — so a broken `pkgs/` derivation fails CI even if no host uses it.

## Architecture

### Module layers

| Layer | Path | Loaded by | Purpose |
|-------|------|-----------|---------|
| Common | `modules/common/` | Both NixOS + HM | Options usable from both sides (`yomi.pilot`, `yomi.theming`, `yomi.location`) |
| NixOS | `modules/nixos/` | NixOS only | System modules (`yomi.cloudflared`, `yomi.hardening`, `yomi.ports`) |
| HM | `modules/home-manager/` | Home-manager only | User modules (`yomi.monitors`, `yomi.persistence`, `yomi.dev`) |
| Shared host | `hosts/nixos/common/` | All hosts | Base: users, networking, boot, filesystems, persistence |
| Per-host | `hosts/nixos/<host>/` | Single host | Hardware, partitions, services |
| Home features | `home/features/` | Per-host HM | cli, desktop, neovim, productivity, wayland |
| Per-host home | `home/<host>.nix` | Single host | Imports `global.nix` + features |

### Flake structure

- `mkHost` (`flake.nix:186`) wires each host: imports `hosts/nixos/<hostname>/`, plus `home/<hostname>.nix` if it exists
- `specialArgs` passes `inputs`, `outputs`, `upkgs` (unstable nixpkgs) to all modules
- `home-manager.extraSpecialArgs` also passes `hostname`
- `nixosModules` = `modules/nixos // modules/common`; `homeModules` = `modules/home-manager // modules/common`
- `systems = ["x86_64-linux"]` only
- `mkPkgs` instantiates both nixpkgs and nixpkgs-unstable with `config.allowUnfree`, handed out via `_module.args.pkgs` and `upkgs`

### Key option namespaces

- `yomi.pilot.*` — user settings (name, email, githubUser, signingKey, sshIdentity)
- `yomi.machine.*` — host capabilities (graphical, interactible, gaming)
- `yomi.ports.*` — port registry, source of truth at `hosts/nixos/common/base/ports.nix`
- `yomi.cloudflared.at.<name>` — tunnel ingress (port, host, enableAnubis, enableIocaine)
- `yomi.nginx.at.<name>` — nginx vhost shorthand
- `yomi.dns.records` — octodns records, also feeding `/etc/hosts`
- `yomi.ssh.extraHostNames` — extra names a host's sshd answers to, pinned in every host's `knownHosts`
- `yomi.persistence.at.{state,cache}.apps.<name>.directories` — impermanence paths
- `yomi.hardening.services.<unit>` — systemd hardening (see below)
- `yomi.restic.{repository,offsite}` — local and off-site backup sets
- `yomi.filesystems.*` — BTRFS rollback + persistPaths
- `yomi.n8n.workflows.<name>` — workflow JSON imported into n8n on inari at start; see `hosts/nixos/inari/services/n8n/AGENTS.md` before touching a workflow or adding a new one

### Service-wrapper exception

Modules wrapping upstream NixOS services use `services.*`: `services.vrising`, `services.steamGameServers`, `services.windrose`, `services.pounce`.

## Hardening

Use `yomi.hardening.services.<unit>`:

```nix
yomi.hardening.services.immich-server = {
  tier = "standard";                                  # base | standard | strict
  readWritePaths = ["/raid5pool/media/photos"];       # appended to upstream's
};
```

- `allowNetwork` adds `AF_NETLINK`, and is a **no-op below `strict`** — that is the only tier restricting address families
- `allowDevices` drops `PrivateDevices`; `allowSubprocesses` widens `SystemCallFilter`
- The tier resolves to one attrset before the module system sees it, so relaxations replace rather than append

**Check the unit name exists before writing it.** `systemd.services.<name>` *creates* a unit, so a typo or a guessed name yields a unit with no `ExecStart` that systemd refuses — while the services you meant to harden keep running open. There is no `karakeep.service` (it is `karakeep-{init,web,workers,browser}`) and no `owncloud.service` (it is `ocis`). An assertion now catches this, but check anyway:

```bash
nix eval --json '.#nixosConfigurations.inari.config.systemd.services' \
  --apply 's: builtins.filter (n: builtins.match "immich.*" n != null) (builtins.attrNames s)'
```

Most upstream nixpkgs modules already set `ProtectSystem=strict`. Check before adding anything.

`presets`/`overrides` are the older interface, still used by ~27 call sites. `overrides.network` is sharp — merged into a non-strict tier it *adds* a restriction, and its `mkForce` concatenates lists instead of replacing them. Prefer `yomi.hardening.services` for anything new.

## Code Style

### Nix
- Fold markers: `# {{{ Section Name` / `# }}}`
- Destructured args: `{config, lib, pkgs, ...}:`
- `let cfg = config.yomi.moduleName; in`
- `lib.mkOption` with `type` + `description`; `lib.mkEnableOption` for toggles; `lib.mkDefault` for overridable defaults
- camelCase options, kebab-case packages
- `lib.mkIf cfg.enable` to gate config blocks
- `builtins.toJSON` + `pkgs.writeText` for JSON, never shell heredocs

### Comments
**Write down why, not what.** This repo's best comments record a decision and the evidence behind it — why ZFS is pinned to 2.3, why `systemd.oomd` is force-disabled, why reloading nftables bounces every container. Keep that.

A comment that contradicts the code is worse than none. `# Use keys only` sat above `PasswordAuthentication = true` for as long as the line existed; two files called `ssh_host_ed25519_key.pub` contained a user key for two years. When you change a value, re-read the comment above it.

### Lua (neovim)
Tabs, width 4, max column 120 (`stylua.toml`). Config uses nvf; plugin specs go through `programs.nvf.settings.vim`.

## Secrets

- sops-nix with age encryption; files named `secrets.yaml`, **never commit plaintext**
- Recipients in `.sops.yaml`; `just sops-rekey` after changing them
- Rekeying does **not** revoke past access — every prior revision stays encrypted to the removed key, and this repo is mirrored to a public forge. Removing a recipient means rotating the values too.
- **Modules in `common/` must take a `sopsFile` option.** A relative path resolves against the module's own directory, so `../../secrets.yaml` in `hosts/nixos/common/services/` reaches `hosts/nixos/common/secrets.yaml`, not the host's. Symptom: `sops-install-secrets: the key '<name>' cannot be found`.
- `just ssh-to-age` needs `SSH_TO_AGE_PASSPHRASE` — the pilot's key is passphrase-protected

## Persistence

- impermanence: stateless root on BTRFS (amaterasu) and ZFS (inari)
- `yomi.filesystems.persistPaths` controls `neededForBoot`
- `DynamicUser=true` services auto-persist via `/var/lib/private`
- Home: `yomi.persistence.at.{state,cache}.apps.<name>.directories`
- Anything under `/raid5pool` is **not** covered by impermanence or the local restic sets — it needs an explicit entry in `yomi.restic.offsite.paths`

## Gotchas

### Nix / flake
- **`nixConfig` must be a top-level flake attribute with literal values.** flake-parts' `flake.nixConfig` is silently ignored, and nix refuses a thunk there (`setting 'extra-substituters' is a thunk`) — so it cannot `import` a shared file. `common/caches.nix` is the copy hosts use via `nix.settings`; keep both in step.
- **`nixpkgs.config.allowUnfree` is a NixOS module setting.** It does not reach the flake's own package outputs; those need an explicitly instantiated nixpkgs (`mkPkgs`).
- **List options merge by concatenation.** Two `mkForce` definitions of the same list do not override — they append. Resolve to one value in plain Nix before handing it to the module system.
- **`./file` inside a flake resolves into the flake source store path**, whose hash changes on every commit. Mounting one into a container restarts it on every switch. Use `builtins.path { path = ./file; name = "..."; }`.
- **New files must be `git add`-ed before flake eval** — flakes only see tracked files.
- **nix.package = pkgs.lix**, hyprland follows nixpkgs-unstable, stylix pinned to release-26.05.

### Services
- **`PasswordAuthentication = false` alone does not disable password login.** `KbdInteractiveAuthentication` defaults to true and `UsePAM` backs it with `pam_unix`, so a prompt comes straight back. Set both.
- **A nixpkgs bump can move a language runtime under a package.** karakeep 0.32.0 core-dumped on every start once nodejs 24 arrived (`better_sqlite3.node`, `Assertion failed: (env) != nullptr`); unstable's 0.33.1 is built against nodejs 22. When a service dies with no application error, compare the runtime version across generations.
- **On inari `networking.firewall.enable = false`** — nftables owns the ruleset, so `openFirewall`/`allowedTCPPorts` reach nothing. Ports go in `lanTcpServicePorts`/`lanUdpServicePorts` in `hosts/nixos/inari/networking/nftables.nix`. A warning lists any port that asked and was ignored.
- **Any nftables ruleset change bounces every container**, down to a comment — `postStart` restarts docker, which docker needs in order to reinstall its own rules. Game servers set `--stop-timeout` for this.
- **ghostty** has no home-manager module; install via `home.packages` + `xdg.configFile`.

### Working on inari
- **`sudo` needs a password** (`wheelNeedsPassword = true`), so `sudo -n` fails. Use the `/run/wrappers/bin/sudo` path, and expect to ask a human.
- **The pilot is in `systemd-journal`**, so `journalctl -u <unit>` works without sudo. Read the journal before theorising.
- **Supplementary groups are fixed at session start.** After adding a group, restarting a user service is not enough — `systemctl restart user@$(id -u)` restarts the user manager, and t3code/opencode come back with it (state lives in `~/.t3`, so sessions survive).

## Use the skills you were given

Your harness lists its available skills at session start. **Read that list before starting work, and invoke a skill instead of hand-rolling its job.** Skipping them is the most common way a session here does competent work by a worse method than the one already sitting there.

Route by situation, not by whether you feel you need help:

| When | Invoke |
|------|--------|
| Anything is broken, failing, crashing, hanging or slow | `diagnosing-bugs` — **before** forming a theory |
| Reviewing a diff, or commits that arrived from another machine | `code-review` |
| Before pushing changes to sops, ssh, firewall, hardening or backups | `security-review` |
| Tidying up after a change lands | `simplify` |
| Hooks, permissions, env vars, settings.json | `update-config` |
| Repeated permission prompts are slowing things down | `fewer-permission-prompts` |
| Anything about Claude/Anthropic model ids, pricing, limits or the API | `claude-api` — never answer from memory |
| Recurring or scheduled work | `loop` / `schedule` |
| Writing prose the human will read | `unslop` (its own description says it always applies) |

Not applicable here, so do not reach for them: `gh-fix-ci` and `gh-address-comments` are GitHub Actions, this repo is Forgejo; `security-best-practices` covers python/js/go, not Nix; `init` generates a fresh CLAUDE.md and would discard this file.

Names vary between harnesses and some sessions offer none of these. Match against the list you were actually given rather than this table, and carry on without them if they are absent — but do not silently reimplement one that is present.

## Agent Workflow

1. `hostname`, then `git status -sb` and `git log --oneline -10` — know where you are and what changed
2. Read your harness's skill list and route the task (see above) before choosing a method by hand
3. Search nixos MCP for packages/options; check neighbouring modules for the local pattern
4. `git add` new files immediately (flakes need tracked files)
5. Edit following fold markers and `yomi.*` conventions
6. **Verify with `nix eval`/`nix build` on the produced artifact**, not by re-reading the source
7. `just lint`, then `just nixos-rebuild dry-build <host>` or `nix flake check`
8. Commit each logical change separately; say what was verified and how
9. Switching is the human's call on a machine you are running inside — say what units will restart first
10. Do not create branches or worktrees unless asked
