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
  live = configuration.config;
  preview = extend {yomi.expose.enable = lib.mkForce false;};
  disabled = extend {yomi.web.at.web-fixture = fixture "cloudflare" // {enable = false;};};
  checks = [
    (valid nginx && nginx.yomi.nginx.at.web-fixture.port == 19250 && !builtins.hasAttr "web-fixture" nginx.yomi.cloudflared.at)
    (valid cloudflare && cloudflare.yomi.cloudflared.at.web-fixture.port == 19250)
    (valid pangolin && !builtins.hasAttr "media" pangolin.yomi.cloudflared.at && !builtins.hasAttr "pocket-id" pangolin.yomi.cloudflared.at && !pangolin.yomi.expose.at.media.sso && pangolin.services.pocket-id.settings.APP_URL == "https://auth.hugo-berendi.de")
    (!valid missingGatewayAuth)
    (valid live
      && lib.all (name:
        builtins.hasAttr name live.yomi.cloudflared.at
        && !(builtins.hasAttr name live.yomi.expose.at)
        && !(builtins.hasAttr "inari-web-${name}" live.yomi.expose.blueprint.public-resources)
        && builtins.hasAttr "inari-web-${name}" preview.yomi.expose.blueprint.public-resources) ["media" "pocket-id"])
    (!builtins.hasAttr "web-fixture" disabled.yomi.cloudflared.at)
  ];
in
  assert lib.all (result: result) checks;
    pkgs.writeText "web-endpoint-checks" "Passed transport selection, explicit auth and staged activation checks."
