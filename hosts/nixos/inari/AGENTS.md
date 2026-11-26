# inari

The home server and the home network's router: ZFS with a root dataset rolled
back to `@blank` on every boot, about fifty services, Docker containers, and
nftables and dnsmasq for the LAN on `br0`. Agents often run on inari
itself, inside a user service. Services live in `services/`; read
`services/AGENTS.md` before touching one.

| Path | Holds |
|---|---|
| `default.nix` | imports, host identity, host-wide settings |
| `home.nix` | the pilot's Home Manager settings on inari |
| `services/` | one file or directory per service, imported automatically |
| `networking/` | networkd, nftables, dnsmasq |
| `filesystems/` | ZFS datasets, impermanence, boot |
| `hardware/` | hardware and kernel |
| `images.nix` | container image digests; CI bumps them |
| `lib/` | helpers the services import (not modules) |
| `recovery-local.nix` | written by the recovery wizard when present; see `docs/inari-migration.md` |

## Working on inari

- `sudo` needs a password (`wheelNeedsPassword = true`), so `sudo -n` fails.
  Use `/run/wrappers/bin/sudo` and expect to ask a human.
- The pilot is in `systemd-journal`: `journalctl -u <unit>` works without sudo.
  Read the journal before theorising.
- Supplementary groups are fixed when a session starts. After adding a group,
  restarting a user service is not enough: `systemctl restart user@$(id -u)`
  restarts the user manager, and T3 Code and opencode come back with it.
- Switching is the human's call. Say first what will restart:

  ```bash
  cur=$(readlink -f /run/current-system)
  new=$(nix build --no-link --print-out-paths '.#nixosConfigurations.inari.config.system.build.toplevel')
  for f in $(ls "$cur/etc/systemd/system" "$new/etc/systemd/system" | sort -u); do
    cmp -s "$cur/etc/systemd/system/$f" "$new/etc/systemd/system/$f" || echo "CHANGED $f"
  done
  ```

## Network

- `networking.firewall.enable = false`: nftables owns the ruleset, so
  `openFirewall` and `allowedTCPPorts` reach nothing. A warning lists any port
  that asked. LAN access is granted per service with
  `yomi.network.exposure.<name>` in the service's own file; `nftables.nix`
  accepts `scope = "lan"` on `br0` only.
- Reloading nftables replaces yomi's named tables and leaves Docker's alone.
  Docker is restarted, to reinstall its rules, only when the legacy deletions
  file still flushes the whole ruleset (`networking/nftables.nix`). Game
  containers set `--stop-timeout` for that case.
- LAN clients reach nginx and SSH directly at `yomi.inari.lanIPv4`, which
  defaults to the address in `profiles/inventory.nix`. Away from home,
  NetBird devices reach the same address through inari as routing peer
  (`services/netbird.nix`); its interface gets the LAN's ports in
  `nftables.nix`. Pangolin carries only the public sites.

## State

- Anything not declared under `yomi.persistence.at.*` is gone after a reboot.
- `/raid5pool` is covered neither by impermanence nor by the local restic
  sets; data there needs an entry in `yomi.restic.offsite.paths`.
- `systemd.oomd` is force-disabled while a recurring memory corruption is
  diagnosed; see the comment in `default.nix` before changing it.
