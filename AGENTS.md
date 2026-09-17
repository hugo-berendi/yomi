# Agent Guidelines for Yomi

Flake-based NixOS configuration managing 5 hosts with shared modules, home-manager, sops-nix secrets, and impermanence.

## Hosts

| Host | Role | Notes |
|------|------|-------|
| `amaterasu` | Framework 13 laptop | BTRFS + impermanence, hyprland, desktop |
| `tsukuyomi` | Tower PC (dormant) | Runs Windows now; config kept but excluded from CI and `nix flake check` |
| `inari` | Home server | ZFS, ~40 services, Docker containers |
| `iso` | Installation ISO | Bootable installer |
| `wsl` | WSL environment | No impermanence |

## Commands

```bash
just nixos-rebuild build <host>     # Dry-build (validates without applying)
just nixos-rebuild switch           # Apply locally (auto-detects hostname)
just nixos-rebuild switch <host>    # Apply remotely via SSH
just nixos-rebuild dry-build <host> # Quick eval check
just lint                           # alejandra + stylua + statix + deadnix
just fmt                            # Format everything (runs before pre-commit)
just pre-commit                     # fmt + nix flake check
just check                          # nix flake check --show-trace
just push-wsl-cache                 # Push wsl build to hugo-berendi cachix
```

**Always dry-build before committing changes.** The `nixos-rebuild` justfile recipe is a Python wrapper that auto-detects local vs remote, handles sudo, and passes `--no-reexec` (nixos-rebuild-ng).

## CI

Forgejo Actions (`.forgejo/workflows/`):
- `check-nixos-flake.yml`: push/PR — runs `just lint`, `just check`, builds amaterasu + inari + wsl
- `update-flake-inputs.yml`: daily cron — `nix flake update`, builds all hosts, auto-commits to main if checks pass

## Architecture

### Module layers

| Layer | Path | Loaded by | Purpose |
|-------|------|-----------|---------|
| Common | `modules/common/` | Both NixOS + HM | Options accessible from both sides (`yomi.pilot`, `yomi.theming`, `yomi.location`, `yomi.ports`) |
| NixOS | `modules/nixos/` | NixOS only | System-level modules (`yomi.cloudflared`, `yomi.hardening`, `yomi.dns`) |
| HM | `modules/home-manager/` | Home-manager only | User-level modules (`yomi.monitors`, `yomi.persistence`, `yomi.dev`) |
| Shared host | `hosts/nixos/common/` | All hosts | Base config: users, networking, boot, filesystems, persistence |
| Per-host | `hosts/nixos/<host>/` | Single host | Host-specific: hardware, partitions, services |
| Home features | `home/features/` | Per-host HM | Feature modules: cli, desktop, neovim, productivity, wayland |
| Per-host home | `home/<host>.nix` | Single host | Host-specific HM config (imports global.nix + features) |

### Flake structure

- `mkHost` in `flake.nix:130` wires each host: imports `hosts/nixos/<hostname>/`, conditionally imports `home/<hostname>.nix` if it exists
- `specialArgs` passes `inputs`, `outputs`, `upkgs` (unstable nixpkgs) to all modules
- `home-manager.extraSpecialArgs` also passes `hostname`
- `nixosModules` = `modules/nixos // modules/common` (merged)
- `homeManagerModules` = `modules/home-manager // modules/common` (merged)

### Key option namespaces

- `yomi.pilot.*` — user settings (name, email, githubUser, signingKey, gpgKeygrip, sshIdentity)
- `yomi.machine.*` — host capabilities (graphical, interactible, gaming)
- `yomi.ports.*` — port registry, source of truth at `hosts/nixos/common/base/ports.nix`
- `yomi.cloudflared.at.<name>` — Cloudflare tunnel ingress (submodule with port, host, enableAnubis, enableIocaine)
- `yomi.nginx.at.<name>` — nginx vhost shorthand
- `yomi.dns.records` — octodns DNS records (consumed by `hosts/nixos/common/default.nix` for /etc/hosts)
- `yomi.persistence.at.{state,cache}.apps.<name>.directories` — impermanence paths
- `yomi.theming.*` — stylix-derived primitives (gaps, rounding, blur, colors)
- `yomi.filesystems.*` — BTRFS rollback + persistPaths (shared via `hosts/nixos/common/filesystems/`)
- `yomi.hardening.presets.{base,standard,strict}` — systemd hardening tiers
- `yomi.location.*` — lat/long for wlsunset

### Service-wrapper exception

Modules wrapping upstream NixOS services use `services.*` instead of `yomi.*`: `services.vrising`, `services.steamGameServers`, `services.windrose`, `services.pounce`. This matches upstream conventions.

## Code Style

### Nix
- Fold markers: `# {{{ Section Name` and `# }}}`
- Destructured args: `{config, lib, pkgs, ...}:`
- `let cfg = config.yomi.moduleName; in` pattern
- `lib.mkOption` with `type` + `description` always
- `lib.mkEnableOption` for boolean toggles
- `lib.mkDefault` for overridable defaults
- camelCase for options, kebab-case for packages
- Custom options under `yomi.*` (except service-wrappers, see above)
- No comments unless requested — code is self-documenting
- Use `builtins.toJSON` + `pkgs.writeText` for JSON generation, never shell heredocs
- Use `lib.mkIf cfg.enable` to gate module config blocks

### Lua (neovim config)
- Tabs, width 4, max column 120 (`stylua.toml`)
- Neovim config uses nvf (not LazyVim). Plugin specs go through `programs.nvf.settings.vim`

## Secrets

- sops-nix with age encryption
- Secret files named `secrets.yaml` — **never commit their contents, only structure/references**
- Keys defined in `.sops.yaml` (age + SSH keys)
- `just sops-rekey` to rekey all secret files
- `just ssh-to-age` to convert SSH key to age key
- Modules that need secrets: add a `sopsFile` option (see vrising, meilisearch patterns), don't hardcode host paths

## Persistence

- impermanence module: stateless root on BTRFS (amaterasu/tsukuyomi) and ZFS (inari)
- `yomi.filesystems.persistPaths` controls `neededForBoot` paths
- `DynamicUser=true` services auto-persist via `/var/lib/private`
- Home: `yomi.persistence.at.{state,cache}.apps.<name>.directories`

## Gotchas

- **nix.package = pkgs.lix** — Lix is the default Nix implementation (`hosts/nixos/common/nix.nix`)
- **hyprland follows nixpkgs-unstable** — not nixpkgs. Breakages can happen on unstable bumps.
- **stylix release-26.05** — pinned to release branch, not master
- **permittedInsecurePackages** — 4 entries: `electron-39.8.10` (bitwarden), `olm-3.2.16` (matrix), `pnpm-10.29.2` and `pnpm-9.15.9` (build tools). Remove stale entries when packages update, and keep this count in step with `common/nixpkgs.nix`.
- **Build failures from insecure packages** — nixpkgs marks packages insecure; add to `common/nixpkgs.nix` `permittedInsecurePackages` only if the package is actually needed
- **ghostty** — no home-manager module exists in the ghostty flake. Install via `home.packages` + `xdg.configFile` (see `home/features/desktop/ghostty.nix`)
- **wsl and iso don't use impermanence** — `yomi.filesystems.btrfs.enable` defaults to false
- **New files must be `git add`-ed before flake eval** — flakes only see git-tracked files. Untracked new files cause "path not found" errors.
- **home-manager backupFileExtension = "backy"** — HM backups old configs with `.backy` extension

## Agent Workflow

1. Search nixos MCP for packages/options before writing Nix code
2. Check existing patterns in neighboring modules
3. Edit files following fold marker + yomi.* conventions
4. `git add` any new files immediately (flakes need tracked files)
5. Dry-build: `just nixos-rebuild dry-build <host>` or `nixos-rebuild dry-build --flake .#<host>`
6. Run `just lint` before committing
7. Commit each logical change separately with descriptive messages
8. Do not create branches or worktrees unless explicitly asked
