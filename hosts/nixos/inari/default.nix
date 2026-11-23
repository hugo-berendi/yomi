{
  config,
  lib,
  ...
}: {
  # {{{ Imports
  imports =
    [
      ../common/profiles/server.nix

      ./networking
      ./filesystems
      ./hardware
      ./memory-limits.nix
      ./nix-builds.nix
      ./auto-upgrade.nix

      # Preserve the merge order of system packages, tmpfiles and backup paths.
      ./services/diabetes
      ./services/protonmail-bridge
      ./services/forgejo
      ./services/radicale
      ./services/restic
      ./services/valheim.nix
      ./services/zfs/default.nix
      ./services/comics.nix
      ./services/media
      ./services/pelican
      ./services/t3code/default.nix
      ./services/changedetection.nix

      # Network access, identity and discovery
      ../common/services/anubis.nix
      ./services/adguard-home.nix
      ./services/expose/default.nix
      ./services/octodns-ddns.nix
      ./services/playit.nix
      ./services/pocket-id.nix

      # Monitoring and notifications
      ./services/alerting
      ./services/ntfy.nix
      ./services/msmtp.nix
      ./services/gatus.nix
      ./services/healthchecks.nix
      ./services/scrutiny.nix
      ./services/beszel.nix
      ./services/prometheus.nix
      ./services/grafana/default.nix
      ./services/loki.nix
      ./services/alloy.nix

      # Code, automation and AI
      ./services/n8n
      ./services/llama-cpp
      ./services/cliproxyapi.nix
      ./services/opencode.nix

      # Personal and household applications
      ./services/homepage/default.nix
      ./services/hugo-berendi-de.nix
      ./services/proton-mail-sorter
      ./services/matrix
      ./services/actual
      ./services/paperless.nix
      ./services/karakeep.nix
      ./services/microbin.nix
      ./services/mealie.nix
      ./services/calsync.nix
      ./services/nextcloud.nix
      ./services/stirling-pdf.nix
      ./services/searxng

      # Media
      ./services/immich.nix
      ./services/audiobookshelf.nix

      # Game servers
      ./services/vrising.nix
      ./services/windrose.nix
    ]
    # The wizard saves hardware choices alongside the restored checkout.
    ++ lib.optional (builtins.pathExists ./recovery-local.nix) ./recovery-local.nix;
  # }}}

  system.stateVersion = "24.05";

  yomi.pilot.name = "hugob";
  yomi.diabetes.enable = true;
  # The imported weeks were checked against Glooko's CGM web summary.
  yomi.diabetes.weeklyEmailEnable = true;
  yomi.machine.interactible = true;
  yomi.containers.enable = true;
  yomi.postgres.enable = true;
  yomi.wireless.enable = false;
  yomi.anubis.enable = true;
  yomi.meilisearch.sopsFile = ./secrets.yaml;
  yomi.meilisearch.environment = "production";

  # Keep systemd-oomd out of the memory-reclaim path while diagnosing the
  # recurring corruption. EFI-pstore later showed that oomd was merely the
  # current task in some crashes, not their common cause.
  # Remove once the recurring corruption is resolved, and re-test after the
  # hardware migration (docs/inari-migration.md), which may remove its cause.
  systemd.oomd.enable = lib.mkForce false;

  # The configured root dataset is rolled back to @blank on every boot. Ensure the
  # home mountpoint itself follows the pilot user's current dynamically
  # allocated UID before Home Manager starts; persisted contents are separate
  # mounts below this directory.
  systemd.tmpfiles.rules = let
    pilot = config.users.users.${config.yomi.pilot.name};
  in ["d ${pilot.home} ${pilot.homeMode} ${pilot.name} ${pilot.group} -"];

  # {{{ Machine ids
  networking.hostName = "inari";
  networking.hostId = "14725dd3";
  # }}}
  # {{{ Bootloader
  boot.loader.systemd-boot.enable = true;
  # }}}
  # {{{ DNS records
  # LAN clients reach nginx and SSH directly. Pangolin provides the same
  # hostnames as private aliases when away from home.
  yomi.dns.records = [
    {
      at = config.networking.hostName;
      type = "A";
      value = config.yomi.inari.lanIPv4;
    }
  ];
  # }}}
}
