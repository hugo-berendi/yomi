{
  pkgs,
  configuration,
}: let
  inherit (pkgs) lib;
  extend = module: (configuration.extendModules {modules = [module];}).config;
  valid = c: lib.all (a: a.assertion) c.assertions;
  fixture = transport: {
    port = 19250;
    inherit transport;
    authentication = "application";
  };
  nginx = extend {yomi.web.at.web-fixture = fixture "nginx";};
  cloudflare = extend {yomi.web.at.web-fixture = fixture "cloudflare";};
  pangolin = extend {
    yomi.expose = {
      enable = true;
      environmentFile = "/run/fixture-newt";
    };
    yomi.web.at = {
      media = {
        transport = lib.mkForce "pangolin";
        stagePangolin = lib.mkForce false;
      };
      pocket-id = {
        transport = lib.mkForce "pangolin";
        stagePangolin = lib.mkForce false;
      };
    };
  };
  missingGatewayAuth = extend {yomi.web.at.web-fixture = fixture "cloudflare" // {authentication = "gateway";};};
  accidentalStage = extend {
    yomi.expose = {
      enable = true;
      environmentFile = "/run/fixture-newt";
    };
  };
  disabled = extend {yomi.web.at.web-fixture = fixture "cloudflare" // {enable = false;};};
  checks = [
    (valid nginx && nginx.yomi.nginx.at.web-fixture.port == 19250 && !builtins.hasAttr "web-fixture" nginx.yomi.cloudflared.at)
    (valid cloudflare && cloudflare.yomi.cloudflared.at.web-fixture.port == 19250)
    (valid pangolin && !builtins.hasAttr "media" pangolin.yomi.cloudflared.at && !builtins.hasAttr "pocket-id" pangolin.yomi.cloudflared.at && !pangolin.yomi.expose.at.media.sso && pangolin.services.pocket-id.settings.APP_URL == "https://auth.hugo-berendi.de")
    (!valid missingGatewayAuth)
    (!valid accidentalStage)
    (!builtins.hasAttr "web-fixture" disabled.yomi.cloudflared.at)
  ];
in
  assert lib.all (result: result) checks;
    pkgs.writeText "web-endpoint-checks" "Passed transport selection, explicit auth and staged activation checks."
