# How the yomi options fit together

[options.md](options.md) lists every `yomi.*` option; it is generated and
always current. This page explains how the main ones work together. To see
what a single service sets, run `just explain <service> [host]`; to find who
sets an option, `just where <option>`.

## A service on inari

A service is one file or directory in `hosts/nixos/inari/services/`. The
host imports every entry there (`lib/import-dir.nix`; names starting with `_`
are skipped), so adding a service is adding that file. `just new-service
<name>` writes a starting point with a free port.

Everything the service needs from the rest of the system is declared in that
file:

| What | Option |
|---|---|
| its port numbers | `yomi.ports.<name>` |
| an HTTP endpoint | `yomi.web.at.<name>` |
| a tile on the homepage dashboard | `yomi.web.at.<name>.homepage` |
| LAN access to a raw port | `yomi.network.exposure.<name>` |
| a Pangolin private resource or raw TCP/UDP forward | `yomi.expose.private`, `yomi.expose.tcp`, `yomi.expose.udp` |
| persisted state | `yomi.persistence.at.<location>.apps.<name>` |
| off-site backup of data outside persistence | `yomi.restic.offsite.paths` |
| secrets | `sops.secrets.*` with an explicit `sopsFile` |

## Ports

`yomi.ports` maps names to port numbers. Each service sets its own entries;
`modules/nixos/ports.nix` keeps only the ports more than one host reads
(iocaine, meilisearch, opencode). Evaluation fails when two
entries share a number, and the message names both.

## HTTP endpoints

`yomi.web.at.<name>` publishes an HTTP service. It requires two decisions:

- `transport`: `nginx` serves it on the LAN, with a certificate from ACME.
  `pangolin` also publishes it on the internet through ebisu's Pangolin
  gateway and the newt connector on inari.
- `authentication`: who checks requests. `application` means the service has
  its own login; `gateway` means Pangolin's SSO does (Pangolin transport
  only); `proxy` means nginx sends the browser through Pocket ID first, with
  oauth2-proxy (nginx transport only; inari's `services/oauth2-proxy`);
  `none` deliberately allows anonymous access. A Pangolin endpoint with
  `none` is open to the whole internet, so it draws a warning until
  `publicReason` says why.

`port` defaults to the `yomi.ports` entry of the same name. Other settings:
`host` (default `<subdomain>.<domain>`), `subdomain`,
`protocol`, `proxyAddress`, `dns.{enable,zone,name}`,
`monitor.{enable,name,group,path,interval,conditions}` for Gatus,
`clientMaxBodySize` (nginx only), and for Pangolin `enableAnubis` and
`pangolin.{users,roles,rules,allowedCountries,blockedCountries,
blockedASNs,healthCheck,additionalTargets,…}`. `url` is read-only.

`homepage = { group; name; icon; description; widget; }` puts a tile on
inari's homepage dashboard (`lab.<domain>`) that links to the endpoint's
`url`. The dashboard (`hosts/nixos/inari/services/homepage/default.nix`)
declares the option, collects every tile and sorts each group by name;
`group` must name a group it lays out. A `widget` is passed to homepage-dashboard
unchanged; its API keys come from `{{HOMEPAGE_VAR_*}}` placeholders filled
from the `homepage_env` secret. Tiles that are not an endpoint of their own,
such as an external site, are listed in the dashboard's file. The option
exists only on a host that runs the dashboard.

`yomi.web.at` writes `yomi.nginx.at` or `yomi.expose.at`. Set
`yomi.nginx.at` directly only to serve static files (`files`), as the two
Matrix web clients do.

With `enableAnubis` the chain is Pangolin, a loopback nginx listener, Anubis,
then the application. The Anubis and proxy ports are derived from the
endpoint's port and join the port registry, so collisions fail evaluation.

## Reachability on inari

inari runs nftables with `networking.firewall.enable = false`, so
`openFirewall` and `allowedTCPPorts` reach nothing; a warning lists any port
that asked. LAN access to a raw port is granted explicitly:

```nix
yomi.network.exposure.windrose-direct = {
  interface = "br0";
  protocols = ["tcp" "udp"];
  service = "windrose";
};
```

`port` defaults to `yomi.ports.<name>`. inari accepts `scope = "lan"` on
`br0` only and rejects anything else until a reviewed rule exists. Docker's
published ports need separate review.

Away from home, NetBird devices reach inari as the LAN does. ebisu runs the
NetBird server (`hosts/nixos/ebisu/netbird.nix`), inari is its routing peer
(`hosts/nixos/inari/services/netbird.nix`), and the NetBird interface gets the
same ports as `br0`. Routes, the exit node and access policies are set in
NetBird's dashboard.

Pangolin still provides private access too, until its private resources are
removed: `yomi.expose.private.<name>` defines a client resource (`mode` host,
cidr, http, ssh, inference or exit-node; `destination`, `alias`, `tcpPorts`,
`udpPorts`, `users`, `roles`). `yomi.expose.tcp` / `yomi.expose.udp` forward a
raw public port.

## Persistence and backups

The root filesystem is rolled back on every boot. System state that must
survive is declared under `yomi.persistence.at.<location>.apps.<name>`;
each location has a backing `path`, and applications list `directories`
(`directory`, `user`, `group`, `mode`) and `files`. `backupSets` assigns
those paths to named restic sets explicitly: nothing is backed up merely
because it is persistent. `yomi.persistence.inventory` shows the evaluated
ownership and assignments. Services with `DynamicUser` persist through
`/var/lib/private`.

`yomi.restic.sets.<name>` defines a backup set (`paths`, `exclude`,
`repository` or `repositoryFile`, `passwordFile`, `environmentFile`,
`pruneOpts`, `checkOpts`, `timerConfig`, `requires`, …). The common policy
declares `data` and `state`; the B2 helper declares `offsite` and
`offsite-check`. Every enabled set reports success metrics.

Anything under `/raid5pool` is covered neither by impermanence nor by the
local sets: it needs an entry in `yomi.restic.offsite.paths`.

Home Manager has its own `yomi.persistence.at.<location>.apps.<name>`.
`excludeFromLocalBackups = true` keeps an application out of the local
`data` and `state` sets. WSL disables persistence on both sides.

## Sandboxing

Use native `systemd.services.<unit>.serviceConfig` beside the service. There
are no hardening tiers. Keep what the upstream module sets and add only
reviewed local requirements; use `mkForce` on a single conflicting directive,
with a reason. Lists merge by concatenation, even when both definitions are
forced.

`just hardening-report <host>` reports the evaluated settings and where each
comes from; `--json` saves a baseline and `--baseline FILE` compares with it.
`just security-audit` inspects the running generation. Unset directives can
be implied by systemd, especially with `DynamicUser`, and an exposure score is
not a vulnerability assessment.

## Game servers

The native Windrose module is separate from inari's Windrose container. It
takes `passwordFile`, loaded through systemd credentials into a privately
written JSON file at start; no password belongs in a Nix string.

## Checks

`checks.x86_64-linux.custom-options` exercises endpoint overrides, disabled
entries, proxy chains, DNS validation, port allocation, backup ordering,
persistence ownership, sandbox requirements and the native game modules.
`checks.x86_64-linux.persistence` checks that WSL has no persistence entries
while the physical hosts keep theirs, and runs a real local restic backup of
included and excluded files. `checks.x86_64-linux.options-doc` fails when
[options.md](options.md) is stale.
