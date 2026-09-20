# Custom options

Reusable NixOS modules live in `modules/nixos`; host defaults and credentials live under `hosts/nixos`.

## Service sandboxing

Use native `systemd.services.<unit>.serviceConfig` beside the service definition. The old `yomi.hardening` tiers and relaxation flags were removed. Keep upstream settings and add only reviewed local requirements. Use `mkForce` only on a specific conflicting directive, with a reason. Lists merge by concatenation, including two equally forced definitions.

The migration preserves the previous evaluated sandbox settings. It does not try to increase restrictions or optimize systemd's exposure score. Runtime requirements differ between web applications, model workers, hardware collectors and containers.

`just hardening-report inari` reports the evaluated settings, contributing module files and generated unit paths without activating anything. Save a baseline with `just hardening-report inari --json > baseline.json`, then compare with `just hardening-report inari --baseline baseline.json`. Missing settings can have implied values, especially with `DynamicUser`. `just security-audit` inspects the running generation instead.

## HTTP endpoints

Both `yomi.nginx.at.<name>` and `yomi.cloudflared.at.<name>` accept:

- `enable`, defaulting to true. A disabled entry creates no proxy, DNS or monitoring resources and needs no port.
- `host`, defaulting to `<subdomain>.<domain>`; `url` is a read-only HTTPS URL derived from it.
- `protocol` and `proxyAddress` for the upstream application, plus `port`. nginx alternatively accepts `files`.
- `dns.enable`, `dns.zone`, and `dns.name`. Managed DNS must match `host`; turn DNS off for externally managed names.
- `monitor.enable`, `monitor.name`, `monitor.group`, `monitor.path`, `monitor.interval`, and `monitor.conditions`. Inari's Gatus configuration consumes enabled checks and supplies its existing email alert policy.

For example:

```nix
yomi.nginx.at.example = {
  host = "app.example.org";
  dns = { zone = "example.org"; name = "app"; };
  port = 9000;
  monitor = { enable = true; path = "/health"; };
};
```

Cloudflare entries can enable Anubis and iocaine independently. With both enabled the chain is Cloudflare, a loopback nginx listener, Anubis, then the application. `anubis.port`, `anubis.metricsPort` and `proxyPort` have offset defaults but can be set explicitly. Enabled listeners join the port registry so collisions and overflow fail evaluation.

nginx starts by default only when it has enabled endpoints. iocaine starts when a tunnel endpoint uses it. Tailscale is explicitly enabled on the physical hosts, not on the installer or WSL.

DNS apex records use `at = ""`; `null` is normalized to the same representation. TTLs must be positive. Identical records are deduplicated across hosts; conflicting records are rejected when generating zones. Use a value list for multiple records of the same type.

## Network exposure

`yomi.ports` allocates numbers. `yomi.network.exposure` grants reachability separately:

```nix
yomi.network.exposure.example = {
  port = config.yomi.ports.example;
  service = "example";
  interface = "br0";
  scope = "lan";
  protocols = ["tcp"];
};
```

Inari consumes LAN grants on `br0` and rejects unsupported scopes and interfaces. Upstream `openFirewall` requests never become grants automatically. Extending access to another network requires implementing and reviewing the corresponding firewall rule. Docker's published ports still need separate review.

## Backup sets and persistence

`yomi.restic.sets.<name>` accepts `enable`, `paths`, `exclude`, `repository` or `repositoryFile`, `passwordFile`, `environmentFile`, `initialize`, `pruneOpts`, `checkOpts`, `extraOptions`, `extraBackupArgs`, `timerConfig`, and `requires`. The last field lists units that must complete before backup, such as `postgresqlBackup.service`.

The common host policy still declares `data` and `state`. Existing `repository`, `extraOptions` and `offsite` settings remain supported; the B2 helper declares `offsite` and `offsite-check` sets. Every enabled set receives success metrics. Disabling a set removes its unit and metrics writer. Restic credentials and ACME credentials have explicit `sopsFile` options; their shared files are selected in host policy.

System persistence is grouped under `yomi.persistence.at.<location>.apps.<name>`. Each location has a backing `path`; applications declare `directories` with `directory`, `user`, `group` and `mode`, and optional `files`. `backupSets` explicitly assigns these live paths to named enabled Restic sets. Nothing is backed up merely because it is persistent. `yomi.persistence.inventory` exposes the evaluated ownership and assignments.

Home Manager's persistence module remains separate. `yomi.terminal.command` and `execCommand` replace untyped terminal settings. NixOS `yomi.machine.audio` and `bluetooth` default to `graphical` but can be selected independently.

## Game services

The native Windrose module remains separate from inari's container deployment. It accepts `passwordFile`, loaded through systemd credentials and inserted into an atomically replaced private JSON file at startup. The unsupported `inviteCode` option was removed. No password belongs in a Nix string or store-backed configuration.

`checks.x86_64-linux.custom-options` exercises endpoint overrides, disabled entries, proxy chains, DNS validation, port allocation, backup ordering, persistence ownership, sandbox requirements, and enabled native game modules without starting services.
