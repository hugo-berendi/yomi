# Yomi (黄泉)

> [!IMPORTANT]
> In the development of this config AI was used.

Yomi is the declarative NixOS and Home Manager configuration for five machines
and a self-hosted homelab. It is based on
[everything-nix](https://github.com/prescientmoon/everything-nix).

## Hosts

| Host                                  | Role                                                   |
| ------------------------------------- | ------------------------------------------------------ |
| [amaterasu](./hosts/nixos/amaterasu/) | Framework 13 laptop                                    |
| [tsukuyomi](./hosts/nixos/tsukuyomi/) | Dormant desktop configuration (currently runs Windows) |
| [inari](./hosts/nixos/inari/)         | ZFS home server and container host                     |
| [iso](./hosts/nixos/iso/)             | Installation and recovery ISO                          |
| [wsl](./hosts/nixos/wsl/)             | WSL environment                                        |

## Highlights

- NixOS and Home Manager configurations assembled through flake-parts
- Hyprland desktop with consistent Stylix theming
- Neovim configured through nvf
- ZFS and Btrfs systems with impermanence
- Secrets encrypted with sops-nix and age
- Central service-port registry and declarative DNS
- Self-hosted services behind nginx, Cloudflare Tunnel, or Tailscale
- Automated system snapshots and Restic backups

## Repository layout

| Location                       | Purpose                                         |
| ------------------------------ | ----------------------------------------------- |
| [`common`](./common)           | Shared NixOS and Home Manager configuration     |
| [`dns`](./dns)                 | Declarative DNS records and OctoDNS integration |
| [`home`](./home)               | Home Manager configurations and features        |
| [`hosts/nixos`](./hosts/nixos) | Host-specific NixOS configurations              |
| [`modules`](./modules)         | Reusable Yomi modules and options               |
| [`overlays`](./overlays)       | Nixpkgs overlays                                |
| [`pkgs`](./pkgs)               | Custom packages                                 |
| [`scripts`](./scripts)         | Installation and recovery helpers               |

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

## Adding a host

1. Create `hosts/nixos/<hostname>/default.nix` and import `../common`.
2. Add the hardware and filesystem configuration.
3. Create `home/<hostname>.nix` when the host uses Home Manager.
4. Register the host in `flake.nix` with `mkHost`.
5. Add DNS records, back up the host's private keys with `just export-keys`, and
   pin its verified public host key with `just import-host-key <hostname>`. The
   pilot's `keys/id_ed25519.pub` grants login; `keys/ssh_host_ed25519_key.pub`
   identifies the machine.
6. Run `just nixos-rebuild dry-build <hostname>` and `just lint`.

## Conventions

Custom options live under `yomi.*`. Service ports are allocated in
[`hosts/nixos/common/base/ports.nix`](./hosts/nixos/common/base/ports.nix),
secrets remain encrypted in `secrets.yaml` files, and host-specific state is
persisted explicitly. See [`AGENTS.md`](./AGENTS.md) for architecture details
and contributor rules.
