# Services on inari

Every entry here is one service: a `<name>.nix` file, or a `<name>/`
directory with a `default.nix`. `../default.nix` imports all of them through
`lib/import-dir.nix`, so there is no list to edit. A helper that is not a
module lives inside its service's directory, or is named `_something.nix`.

## Adding a service

```bash
just new-service <name>          # writes <name>.nix with a free port and stages it
just explain <name>              # what it now brings to the host
just nixos-rebuild dry-build inari
```

Declare everything the service needs in its own file:

| Need | Write | Notes |
|---|---|---|
| a port | `yomi.ports.<name> = 85xx;` | `new-service` picks a free one; a clash fails evaluation |
| a web UI or API | `yomi.web.at.<name> = { transport; authentication; };` | `port` defaults to `yomi.ports.<name>`; see below |
| a health check | `monitor.enable = true;` in that entry | Gatus picks it up |
| LAN access to a raw port | `yomi.network.exposure.<name>.interface = "br0";` | `br0` and `scope = "lan"` only |
| access from outside the LAN | `yomi.expose.private.<name>` or `yomi.expose.tcp/udp.<name>` | Pangolin, through ebisu |
| state that survives reboots | `yomi.persistence.at.state.apps.<name>.directories` | the root is wiped on boot |
| data under `/raid5pool` backed up | `yomi.restic.offsite.paths` | the local sets do not cover it |
| a secret | `sops.secrets.<key>.sopsFile = ../secrets.yaml;` | `../../secrets.yaml` from a subdirectory |
| a container | `virtualisation.oci-containers.containers.<name>` with `image = (import ../images.nix).<name>` | CI bumps the digest |

### `yomi.web.at`

- `transport = "nginx"` serves the LAN only. `"pangolin"` also publishes the
  service on the internet through ebisu.
- `authentication` says who checks requests: `"application"` (its own
  login), `"gateway"` (Pangolin SSO; Pangolin only) or `"none"`. Write what is
  true, not what you would like: the value is how a reader learns which
  services anyone on the LAN can use. Check it by requesting the service
  anonymously.
- A Pangolin endpoint with `authentication = "none"` is open to the whole
  internet and draws a warning until `publicReason` says why (the personal
  website, calsync's legal pages). An nginx endpoint is private and needs no
  reason.
- `clientMaxBodySize` for uploads above nginx's 1M default (nginx only).
- Read URLs as `config.yomi.web.at.<name>.url`. Set `yomi.nginx.at` directly
  only to serve static files.

See `docs/concepts.md` for the whole model and `docs/options.md` for every
option.

## Before changing a service

- Check the real unit name in the evaluated configuration (`just explain`).
  Defining `systemd.services.<name>` creates the unit, so a typo makes an
  empty one; there is no `karakeep.service` or `nextcloud.service`.
- Sandbox with native `systemd.services.<unit>.serviceConfig`. Upstream
  modules usually sandbox already: run `just hardening-report inari` first,
  add only what is missing, and use `mkForce` on single directives with a
  reason.
- A file mounted into a container must come from `builtins.path`, not
  `./file`, or the container restarts on every commit.
- Python or JavaScript that a service runs sits in its directory with a
  `package.nix` or a `builtins.path` whose filter leaves out the Nix files and
  the README, so editing those does not restart the service. Tests for it are
  exposed under `checks` (`checks/default.nix`).
- n8n workflows are declared in `yomi.n8n.workflows`; read `n8n/README.md`
  before touching one.

Documentation for a service goes in its directory as `README.md`.
