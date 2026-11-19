{
  config,
  pkgs,
  ...
}: let
  # OIDC login is still only on a preview branch upstream. The earlier
  # preview-OIDC pin (September 2025) sat 595 commits behind v3.5.0, without
  # the 3.1.0 security release; preview-new-oidc is the maintained successor.
  # Its build matches nixpkgs' seerr (same node and pnpm), so only the source
  # and its pnpm dependencies are swapped.
  jellyseerr-oidc-src = pkgs.fetchFromGitHub {
    owner = "seerr-team";
    repo = "seerr";
    rev = "b1312ccd8776de04420a825f23b3f2d9aab2f2f9";
    hash = "sha256-VUZbYfHGluBF58nuTueTZfEfK5EIKtQTwtfdAbePbNU=";
  };

  jellyseerr-oidc = pkgs.seerr.overrideAttrs (oldAttrs: {
    version = "preview-new-oidc";
    src = jellyseerr-oidc-src;
    pnpmDeps = oldAttrs.pnpmDeps.overrideAttrs {
      src = jellyseerr-oidc-src;
      outputHash = "sha256-gqjz0DM0VYdFKTkoKPG9fjAwZlKeQZS1GB4wwUcwZ9M=";
    };
  });
in {
  # {{{ reverse proxy
  yomi.web.at.request-media = {
    port = config.yomi.ports.jellyseerr;
    transport = "pangolin";
    authentication = "application";
    monitor = {
      enable = true;
      name = "jellyseerr";
    };
    pangolin = {
      labels = ["media"];
      healthCheck = {
        enable = true;
        path = "/api/v1/status";
      };
    };
  };
  yomi.cloudflared.at.request-media = {
    inherit (config.yomi.web.at.request-media) host port protocol proxyAddress;
    dns.enable = false;
  };
  # }}}
  #{{{ settings
  nixarr.seerr = {
    enable = true;
    port = config.yomi.web.at.request-media.port;
    vpn.enable = false;
    package = jellyseerr-oidc;
  };
  # }}}
}
