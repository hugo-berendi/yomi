{
  config,
  inputs,
  lib,
  ...
}: {
  # {{{ Imports
  imports = [
    ../common
    inputs.hermes-agent.nixosModules.default

    ./networking
    ./filesystems
    ./hardware
    ./memory-limits.nix

    ../common/services/anubis.nix
    ../common/services/meilisearch.nix

    ./services/ollama.nix
    ./services/llama-cpp.nix
    ./services/karakeep.nix
    ./services/n8n.nix
    ./services/affine.nix
    ./services/cloudflared.nix
    ./services/forgejo
    ./services/guacamole
    ./services/paperless.nix
    ./services/paperless-ai.nix
    ./services/homepage.nix
    ./services/msmtp.nix
    ./services/invidious.nix
    ./services/jupyter.nix
    ./services/microbin.nix
    ./services/mealie.nix
    ./services/radicale.nix
    ./services/redlib.nix
    ./services/restic.nix
    ./services/valheim.nix
    ./services/vaultwarden.nix
    ./services/immich.nix
    ./services/music
    ./services/searxng.nix
    ./services/zfs.nix
    ./services/adguard-home.nix
    ./services/comics/default.nix
    ./services/media
    ./services/home-assistant.nix
    ./services/ntfy.nix
    ./services/audiobookshelf.nix
    ./services/gatus.nix
    ./services/scrutiny.nix
    ./services/miniflux.nix
    ./services/vikunja.nix
    ./services/healthchecks.nix
    # ./services/bookstack.nix
    ./services/pocket-id.nix
    ./services/prometheus.nix
    ./services/grafana.nix
    ./services/loki.nix
    ./services/playit.nix
    ./services/windrose.nix
    ./services/pelican
    ./services/owncloud.nix
    ./services/stirling-pdf.nix
    ./services/vrising.nix
    ./services/octodns-ddns.nix
    ./services/beszel.nix
    ./services/matrix
    ./services/opencode.nix
    ./services/t3code.nix
    ./services/hermes-agent.nix
    ./services/changedetection.nix
  ];
  # }}}

  system.stateVersion = "24.05";

  yomi.pilot.name = "hugob";
  yomi.machine.interactible = true;
  yomi.containers.enable = true;
  yomi.postgres.enable = true;
  yomi.wireless.enable = false;
  yomi.tailscale.exitNode = true;
  yomi.meilisearch.sopsFile = ./secrets.yaml;
  yomi.meilisearch.environment = "production";

  # systemd-oomd repeatedly panicked the kernel inside cgroup v2 memcg
  # accounting (memory_stat_show/mod_memcg_lruvec_state) due to ZFS ARC's
  # reclaim path not participating cleanly in cgroup memory accounting.
  # Reproduced across kernel 6.12.90 and 6.18.36 alike.
  systemd.oomd.enable = lib.mkForce false;

  # The root dataset is rolled back to zroot@blank on every boot. Ensure the
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
  boot.loader.systemd-boot.configurationLimit = 4;
  # }}}
  # {{{ DNS records
  yomi.dns.records = [
    {
      at = config.networking.hostName;
      type = "A";
      value = "100.83.158.40";
    }
    {
      at = config.networking.hostName;
      type = "AAAA";
      value = "fd7a:115c:a1e0::2401:9e28";
    }
  ];
  # }}}
}
