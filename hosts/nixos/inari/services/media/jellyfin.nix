{
  config,
  inputs,
  ...
}: let
  pkgs-old = import inputs.nixpkgs-old {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.media.port = config.yomi.ports.jellyfin;
  # }}}
  # {{{ Service
  services.jellyfin = {
    enable = true;
    package = pkgs-old.jellyfin;
  };
  # }}}
}
