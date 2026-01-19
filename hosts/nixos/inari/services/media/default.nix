{config, ...}: {
  # {{{ Imports
  imports = [
    ./vpn.nix
    ./bazarr.nix
    ./sonarr.nix
    ./lidarr.nix
    ./radarr.nix
    ./readarr.nix
    ./transmission.nix
    ./jellyseerr.nix
    ./jellyfin.nix
    ./prowlarr.nix
    ./flaresolverr.nix
    ./recyclarr.nix
  ];
  # }}}
  # {{{ Nixarr
  nixarr = {
    enable = true;
    stateDir = "/var/lib/media";
    mediaDir = "/raid5pool/media";
    mediaUsers = ["jellyfin" "sonarr" "radarr" "bazarr"];
  };
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = config.nixarr.stateDir;
      mode = "u=rwx,g=r,o=rwx";
    }
  ];
  # }}}
}
