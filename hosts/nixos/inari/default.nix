{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../common/global
    ../common/users/pilot.nix
    ../common/users/guest.nix
    ../common/optional/oci.nix
    ../common/optional/services/acme.nix
    # ../common/optional/services/kanata.nix
    ../common/optional/services/nginx.nix
    ../common/optional/services/postgres.nix
    ../common/optional/services/syncthing.nix
    # ../common/optional/services/restic

    ./services/commafeed.nix
    # # ./services/ddclient.nix
    # ./services/actual.nix
    ./services/cloudflared.nix
    # ./services/diptime.nix
    ./services/forgejo.nix
    ./services/grafana.nix
    # ./services/guacamole
    ./services/homer.nix
    # ./services/intray.nix
    # ./services/invidious.nix
    ./services/jellyfin.nix
    ./services/jupyter.nix
    ./services/microbin.nix
    # ./services/glance.nix
    # ./services/pounce.nix
    ./services/prometheus.nix
    ./services/qbittorrent.nix # turned on/off depending on whether my vpn is paid for
    ./services/radicale.nix
    ./services/redlib.nix
    # ./services/smos.nix
    ./services/vaultwarden.nix
    ./services/whoogle.nix
    ./services/zfs.nix
    # ./services/ntfy.nix
    ./services/suwayomi.nix
    # {{{ *arr suite
    ./services/sonarr.nix
    ./services/radarr.nix
    ./services/readarr.nix
    ./services/bazarr.nix
    ./services/prowlarr.nix
    # }}}
    # ./services/uptime.nix
    ./services/home-assistant.nix
    # {{{ game servers
    # ./services/playit.nix # tunnel for minecraft
    # ./services/valheim.nix
    # ./services/minecraft.nix
    # }}}

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
