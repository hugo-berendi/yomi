{
  config,
  pkgs,
  ...
}: let
  nodejs-slim = pkgs.nodejs-slim_22;
  pnpm = pkgs.pnpm_9.override {inherit nodejs-slim;};

  jellyseerr-oidc-src = pkgs.fetchFromGitHub {
    owner = "seerr-team";
    repo = "seerr";
    rev = "7f3979411655ef5f65ce4918fe0f8f214403f75e";
    hash = "sha256-EJz1W7ewEczizNRs/X3esjQUwJiTHruo7nkAzyKZbjc=";
  };

  jellyseerr-oidc = pkgs.seerr.overrideAttrs (_oldAttrs: {
    version = "preview-OIDC";
    src = jellyseerr-oidc-src;
    pnpmDeps = pkgs.fetchPnpmDeps {
      pname = "seerr";
      version = "preview-OIDC";
      src = jellyseerr-oidc-src;
      inherit pnpm;
      fetcherVersion = 3;
      hash = "sha256-0CwHkxG3SOSd+xozONnAi7Mr0y+lXdxwJk8mRZf8Bhs=";
    };
    nativeBuildInputs = [
      pkgs.python3
      pkgs.python3Packages.distutils
      nodejs-slim
      pkgs.makeWrapper
      pkgs.pnpmConfigHook
      pnpm
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share
      cp -r -t $out/share .next node_modules dist public package.json jellyseerr-api.yml
      runHook postInstall
    '';

    postInstall = ''
      mkdir -p $out/bin
      makeWrapper '${nodejs-slim}/bin/node' "$out/bin/seerr" \
        --add-flags "$out/share/dist/index.js" \
        --chdir "$out/share" \
        --set NODE_ENV production
    '';
  });
in {
  # {{{ reverse proxy
  yomi.cloudflared.at.request-media.port = config.yomi.ports.jellyseerr;
  # }}}
  #{{{ settings
  nixarr.seerr = {
    enable = true;
    port = config.yomi.cloudflared.at.request-media.port;
    vpn.enable = false;
    package = jellyseerr-oidc;
  };
  # }}}
}
