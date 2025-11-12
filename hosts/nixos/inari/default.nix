{config, ...}: {
  # {{{ Imports
  imports = [
    ../common

    ./networking
    ./filesystems
    ./hardware

    ../common/services/anubis.nix
    ../common/services/meilisearch.nix

    ./services/ollama.nix
    ./services/karakeep.nix
    ./services/n8n.nix
    ./services/actual.nix
    ./services/cloudflared.nix
    ./services/forgejo.nix
    ./services/guacamole
    ./services/paperless.nix
    ./services/paperless-ai.nix
    ./services/homepage.nix
    ./services/msmtp.nix
    ./services/invidious.nix
    ./services/jupyter.nix
    ./services/microbin.nix
    ./services/radicale.nix
    ./services/redlib.nix
    ./services/vaultwarden.nix
    ./services/immich.nix
    ./services/music
    ./services/searxng.nix
    ./services/zfs.nix
    ./services/adguard-home.nix
    ./services/comics/default.nix
    ./services/media
    ./services/home-assistant.nix
    ./services/uptime.nix
    ./services/authentik.nix
    ./services/prometheus.nix
    ./services/grafana.nix
    ./services/loki.nix
    ./services/playit.nix
    ./services/anonaddy.nix
    # ./services/pelican
    ./services/owncloud.nix
    ./services/stirling-pdf.nix
  ];
  # }}}

  system.stateVersion = "24.05";

  yomi.pilot.name = "hugob";
  yomi.machine.interactible = true;
  yomi.containers.enable = true;
  yomi.wireless.enable = false;

  # {{{ Machine ids
  networking.hostName = "inari";
  networking.hostId = "14725dd3";
  # }}}
  # {{{ Bootloader
  boot.loader.systemd-boot.enable = true;
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
