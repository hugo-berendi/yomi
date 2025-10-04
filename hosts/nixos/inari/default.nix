{config, ...}: {
  imports = [
    ../common/global
    ../common/users/pilot.nix
    ../common/users/guest.nix
    ../common/optional/oci.nix
    ../common/optional/quietboot.nix
    ../common/optional/services/acme.nix
    # ../common/optional/services/kanata.nix
    ../common/optional/services/nginx.nix
    ../common/optional/services/postgres.nix
    ../common/optional/services/meilisearch.nix
    ../common/optional/services/syncthing.nix
    # ../common/optional/services/restic

    ./services/ollama.nix
    ./services/karakeep.nix
    ./services/n8n.nix
    # ./services/ddclient.nix
    ./services/actual.nix
    ./services/cloudflared.nix
    ./services/forgejo.nix
    ./services/guacamole
    ./services/paperless.nix
    ./services/homer.nix
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
    ./services/pelican
    ./services/playit.nix
    ./services/owncloud.nix
    ./services/anonaddy.nix

    ./filesystems
    ./hardware
  ];

  # Machine ids
  networking.hostName = "inari";
  networking.hostId = "14725dd3";
  # environment.etc.machine-id.text = "d9571439c8a34e34b89727b73bad3587";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";

  # Bootloader
  boot.loader.systemd-boot.enable = true;

  # Tailscale internal IP DNS records
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
}
