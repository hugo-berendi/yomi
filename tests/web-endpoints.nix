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
  pangolin = extend {yomi.web.at.pocket-id.transport = lib.mkForce "pangolin";};
  missingGatewayAuth = extend {yomi.web.at.web-fixture = fixture "cloudflare" // {authentication = "gateway";};};
  live = configuration.config;
  mediaDns = lib.filter (record: record.at == "media" && record.zone == live.yomi.expose.domain) live.yomi.dns.records;
  preview = extend {yomi.expose.enable = lib.mkForce false;};
  disabled = extend {yomi.web.at.web-fixture = fixture "cloudflare" // {enable = false;};};
  checks = [
    (valid nginx && nginx.yomi.nginx.at.web-fixture.port == 19250 && !builtins.hasAttr "web-fixture" nginx.yomi.cloudflared.at)
    (valid cloudflare && cloudflare.yomi.cloudflared.at.web-fixture.port == 19250)
    (valid pangolin && !builtins.hasAttr "pocket-id" pangolin.yomi.cloudflared.at && pangolin.services.pocket-id.settings.APP_URL == "https://auth.hugo-berendi.de")
    (!valid missingGatewayAuth)
    (valid live
      && builtins.hasAttr "pocket-id" live.yomi.cloudflared.at
      && !(builtins.hasAttr "pocket-id" live.yomi.expose.at)
      && !(live.yomi.expose.blueprint.public-resources ? inari-web-pocket-id)
      && preview.yomi.expose.blueprint.public-resources ? inari-web-pocket-id)
    (!live.yomi.expose.at.media.sso
      && !live.yomi.cloudflared.at.media.dns.enable
      && map (record: record.value) mediaDns == ["${live.yomi.expose.publicHost}."]
      && lib.all (record: !record.enableCloudflareProxy) mediaDns)
    (!builtins.hasAttr "web-fixture" disabled.yomi.cloudflared.at)
  ];
in
  assert lib.all (result: result) checks;
    pkgs.writeText "web-endpoint-checks" "Passed transport selection, explicit auth and staged activation checks."
