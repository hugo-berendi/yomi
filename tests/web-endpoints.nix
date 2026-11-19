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
  missingGatewayAuth = extend {yomi.web.at.web-fixture = fixture "cloudflare" // {authentication = "gateway";};};
  live = configuration.config;
  expectedGatewayDns = subdomain: let
    records = lib.filter (record: record.at == subdomain && record.zone == live.yomi.expose.domain) live.yomi.dns.records;
  in
    map (record: record.value) records
    == ["${live.yomi.expose.publicHost}."]
    && lib.all (record: !record.enableCloudflareProxy) records;
  stagedEndpoint = fixture "cloudflare" // {stagePangolin = true;};
  monitoredUrls = name:
    map (endpoint: endpoint.url) (lib.filter (endpoint: endpoint.name == name && endpoint.group == "Services") live.services.gatus.settings.endpoints);
  staged = extend {yomi.web.at.web-fixture = stagedEndpoint;};
  preview = extend {
    yomi.web.at.web-fixture = stagedEndpoint;
    yomi.expose.enable = lib.mkForce false;
  };
  disabled = extend {yomi.web.at.web-fixture = fixture "cloudflare" // {enable = false;};};
  checks = [
    (valid nginx && nginx.yomi.nginx.at.web-fixture.port == 19250 && !builtins.hasAttr "web-fixture" nginx.yomi.cloudflared.at)
    (valid cloudflare && cloudflare.yomi.cloudflared.at.web-fixture.port == 19250)
    (!valid missingGatewayAuth)
    (valid staged
      && !(staged.yomi.expose.blueprint.public-resources ? inari-web-web-fixture)
      && preview.yomi.expose.blueprint.public-resources ? inari-web-web-fixture)
    (valid live
      && live.services.pocket-id.settings.APP_URL == "https://auth.hugo-berendi.de"
      && !live.yomi.expose.at.pocket-id.sso
      && !live.yomi.cloudflared.at.pocket-id.dns.enable
      && expectedGatewayDns "auth")
    (!live.yomi.expose.at.media.sso
      && !live.yomi.cloudflared.at.media.dns.enable
      && expectedGatewayDns "media")
    (lib.all (name:
      !live.yomi.expose.at.${name}.sso
      && !live.yomi.cloudflared.at.${name}.dns.enable
      && expectedGatewayDns name) ["audiobookshelf" "request-media" "bin" "search" "ntfy"])
    (monitoredUrls "jellyseerr" == ["https://request-media.hugo-berendi.de"])
    (monitoredUrls "microbin" == ["https://bin.hugo-berendi.de"])
    (monitoredUrls "searxng" == ["https://search.hugo-berendi.de"])
    (!builtins.hasAttr "web-fixture" disabled.yomi.cloudflared.at)
  ];
in
  assert lib.all (result: result) checks;
    pkgs.writeText "web-endpoint-checks" "Passed transport selection, explicit auth, staged activation and gateway DNS checks."
