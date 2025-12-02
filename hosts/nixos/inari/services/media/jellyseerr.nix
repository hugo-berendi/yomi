{
  config,
  pkgs,
  lib,
  ...
}: let
  jellyseerr-oidc = pkgs.jellyseerr.overrideAttrs (oldAttrs: {
    version = "preview-OIDC";
    src = pkgs.fetchFromGitHub {
      owner = "seerr-team";
      repo = "seerr";
      rev = "7f3979411655ef5f65ce4918fe0f8f214403f75e";
      hash = "sha256-EJz1W7ewEczizNRs/X3esjQUwJiTHruo7nkAzyKZbjc=";
    };
    pnpmDeps = oldAttrs.pnpmDeps.overrideAttrs {
      src = pkgs.fetchFromGitHub {
        owner = "seerr-team";
        repo = "seerr";
        rev = "7f3979411655ef5f65ce4918fe0f8f214403f75e";
        hash = "sha256-EJz1W7ewEczizNRs/X3esjQUwJiTHruo7nkAzyKZbjc=";
      };
      outputHash = "sha256-yjrlZfObAMj9WOywlsP51wNrbUNh8m1RxtbkjasnEW4=";
    };
  });
in {
  # {{{ reverse proxy
  yomi.cloudflared.at.request-media.port = config.yomi.ports.jellyseerr;
  # }}}
  #{{{ settings
  nixarr.jellyseerr = {
    enable = true;
    port = config.yomi.cloudflared.at.request-media.port;
    vpn.enable = false;
    package = jellyseerr-oidc;
  };
  # }}}
}
