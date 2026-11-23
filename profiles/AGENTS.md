# Profiles

What a kind of machine gets. A host imports exactly one role profile:

| Profile | For | Brings |
|---|---|---|
| `desktop.nix` | amaterasu | base, fleet, Home Manager, the desktop session (both halves), greeter, local restic sets |
| `server.nix` | inari | base, fleet, Home Manager, nixarr, OCI containers, local restic sets, ACME |
| `wsl.nix` | tsukuyomi, wsl-work | NixOS-WSL, base, fleet, Home Manager with `features/wsl.nix`; no impermanence |
| `recovery.nix` | iso | base and fleet only |
| `vps.nix` | ebisu | base only: no desktop, users or monitoring of the home fleet |

The building blocks below them:

| File | Holds |
|---|---|
| `base.nix` | what every host has, the VPS included: nix settings, sops, impermanence, sshd, fish, `/etc/hosts` from the inventory |
| `fleet.nix` | what the home machines share: stylix, the pilot user, the beszel agent, 1Password |
| `home-manager.nix` | Home Manager for the pilot, with `features/default.nix` as the base |
| `nix.nix` | nix settings and binary caches (`common/caches.nix`) |
| `persistence.nix` | impermanence wiring shared by the hosts that use it |
| `services/` | services several hosts run: openssh, restic, syncthing, greetd, anubis, oci |
| `users/` | the pilot and the login keys collected from `hosts/nixos/*/keys/` |
| `inventory.nix` | facts other hosts need about inari and ebisu: addresses, SSH aliases |
| `secrets.yaml` | secrets shared by the home fleet |

## Rules

- `inventory.nix` is plain data on purpose. Do not read a sibling host's
  evaluated configuration instead; building one host would evaluate them all.
  Each host still declares its own view (`yomi.dns.records`,
  `yomi.ssh.extraHostNames`), and assertions fail its build when that view
  and the inventory disagree.
- `nix.nix` reads `common/caches.nix`. The flake's top-level `nixConfig`
  repeats the same list as literals and must be kept in step by hand.
- `secrets.yaml` here is encrypted to the shared host key and the pilot's
  keys (`.sops.yaml`). Removing a recipient does not revoke past access: the
  old revisions stay readable in git history, so rotate the values too.
- A login key goes in `hosts/nixos/<host>/keys/id_*.pub`; the host key there,
  `ssh_host_ed25519_key.pub`, pins the machine in everyone's `knownHosts`
  (`just import-host-key <host>`).
