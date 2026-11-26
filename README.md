# Yomi (黄泉)

> [!IMPORTANT]
> In the development of this config AI was used.

Yomi is the declarative NixOS and Home Manager configuration for six machines
and a self-hosted homelab. It is based on
[everything-nix](https://github.com/prescientmoon/everything-nix).

## Hosts

| Host                                  | Role                                                   |
| ------------------------------------- | ------------------------------------------------------ |
| [amaterasu](./hosts/nixos/amaterasu/) | Framework 13 laptop                                    |
| [ebisu](./hosts/nixos/ebisu/)         | Pangolin gateway VPS                                   |
| [tsukuyomi](./hosts/nixos/tsukuyomi/) | Home PC, NixOS-WSL                                     |
| [inari](./hosts/nixos/inari/)         | ZFS home server and container host                     |
| [iso](./hosts/nixos/iso/)             | Installation and recovery ISO                          |
| [wsl-work](./hosts/nixos/wsl-work/)   | Work laptop, NixOS-WSL                                 |

## Highlights

- NixOS and Home Manager configurations assembled through flake-parts
- Hyprland desktop with consistent Stylix theming
- Neovim configured through nvf
- ZFS and Btrfs systems with impermanence
- Secrets encrypted with sops-nix and age
- One file per self-hosted service: port, endpoint, access, state and backups together
- Services behind nginx on the LAN or a Pangolin gateway, with declarative DNS
- Automated system snapshots and Restic backups

## Repository layout

| Location                       | Purpose                                                    |
| ------------------------------ | ---------------------------------------------------------- |
| [`hosts/nixos`](./hosts/nixos) | One directory per machine; inari's services in `inari/services/` |
| [`profiles`](./profiles)       | What a kind of machine gets: base, fleet, desktop, server, wsl, vps, recovery |
| [`home`](./home)               | The pilot's Home Manager configuration; programs and desktop in `features/`, where `system.nix` files are NixOS |
| [`modules`](./modules)         | The `yomi.*` options and their implementation              |
| [`common`](./common)           | Themes, fonts, browser data and caches for NixOS and Home Manager |
| [`dns`](./dns)                 | Declarative DNS records and OctoDNS integration            |
| [`pkgs`](./pkgs)               | Custom packages                                            |
| [`overlays`](./overlays)       | Nixpkgs overlays                                           |
| [`checks`](./checks)           | Flake checks (hosts and scenario tests)                    |
| [`tests`](./tests)             | Scenario tests and fixtures used by the checks             |
| [`scripts`](./scripts)         | `ci/`, `ops/` and `recovery/` helpers                      |
| [`lib`](./lib)                 | Flake helpers (`mk-host.nix`, `import-dir.nix`)            |
| [`devshells`](./devshells)     | Development shells                                         |
| [`docs`](./docs)               | Concepts, the generated option reference, runbooks         |

## Common commands

Enter the development shell with `direnv allow` or `nix develop`, then use:

```console
just lint
just check
just nixos-rebuild dry-build amaterasu
just nixos-rebuild switch amaterasu
just build-iso
just dns-diff
```

`just check` validates the active host configurations as well as the DNS
outputs. Run a dry build before applying or committing system changes.

The [calendar sync guide](./docs/calendar-sync.md) covers the live sync units and
Google's recurring-event compatibility fix.

## Adding a host

1. Create `hosts/nixos/<hostname>/default.nix` and import one role profile
   from `profiles/` (`desktop.nix`, `server.nix`, `wsl.nix`, `vps.nix` or
   `recovery.nix`).
2. Add the hardware and filesystem configuration.
3. If the profile brings Home Manager, put the host's own settings in
   `home.nix` and add `home-manager.users.<pilot>.imports = [./home.nix];`.
4. Register the host in `flake.nix`.
5. Add stable addresses and SSH aliases to `profiles/inventory.nix` where
   other hosts need them. Add DNS records and back up the host's private keys
   with `just export-keys`. Pin its verified public host key with
   `just import-host-key <hostname>`. The pilot's `keys/id_ed25519.pub`
   grants login; `keys/ssh_host_ed25519_key.pub` identifies the machine.
6. Run `just nixos-rebuild dry-build <hostname>` and `just lint`.

## Adding a service on inari

Run `just new-service <name>`, fill in the file it creates in
`hosts/nixos/inari/services/`, and check it with `just explain <name>`. See
[the services guide](./hosts/nixos/inari/services/AGENTS.md) and
[the concepts](./docs/concepts.md).

## Conventions

Custom options live under `yomi.*` and are listed in
[`docs/options.md`](./docs/options.md). Each service declares its own ports,
secrets remain encrypted in `secrets.yaml` files, and state is persisted
explicitly. See [`AGENTS.md`](./AGENTS.md) for the map and the contributor
rules.
