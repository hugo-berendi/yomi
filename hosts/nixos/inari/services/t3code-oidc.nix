{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.t3codeOidc;
  pilot = config.yomi.pilot.name;
  oidcConfig = pkgs.writeText "t3code-oidc.json" (builtins.toJSON {
    issuer = config.yomi.cloudflared.at.pocket-id.url;
    inherit (cfg) clientId allowedEmails;
    origin = config.yomi.nginx.at.t3code.url;
    clientSecretFile = config.sops.secrets.t3code_oidc_client_secret.path;
  });
in {
  options.yomi.t3codeOidc = {
    enable = lib.mkEnableOption "Pocket ID login issuing ordinary T3 Code browser sessions";
    clientId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Dedicated Pocket ID client ID; register the T3 origin's /auth/oidc/callback URL.";
    };
    allowedEmails = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [config.yomi.pilot.email];
      description = "Verified Pocket ID email addresses allowed full T3 Code access.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.clientId != "" && cfg.allowedEmails != [];
        message = "T3 Code OIDC requires a Pocket ID client ID and an explicit email allowlist.";
      }
    ];
    sops.secrets.t3code_oidc_client_secret = {
      sopsFile = ../secrets.yaml;
      owner = pilot;
    };
    home-manager.users.${pilot}.systemd.user.services.t3code-web.Service.Environment = [
      "T3CODE_OIDC_CONFIG=${oidcConfig}"
    ];
  };
}
