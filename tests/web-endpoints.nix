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
  pangolin = extend {yomi.web.at.web-fixture = fixture "pangolin";};
  missingGatewayAuth = extend {yomi.web.at.web-fixture = fixture "nginx" // {authentication = "gateway";};};
  live = configuration.config;
  expectedGatewayDns = subdomain: let
    records = lib.filter (record: record.at == subdomain && record.zone == live.yomi.expose.domain) live.yomi.dns.records;
  in
    map (record: record.value) records
    == ["${live.yomi.expose.publicHost}."]
    && lib.all (record: !record.enableCloudflareProxy) records;
  stagedEndpoint = fixture "nginx" // {stagePangolin = true;};
  monitoredUrls = name:
    map (endpoint: endpoint.url) (lib.filter (endpoint: endpoint.name == name && endpoint.group == "Services") live.services.gatus.settings.endpoints);
  staged = extend {yomi.web.at.web-fixture = stagedEndpoint;};
  preview = extend {
    yomi.web.at.web-fixture = stagedEndpoint;
    yomi.expose.enable = lib.mkForce false;
  };
  disabled = extend {yomi.web.at.web-fixture = fixture "pangolin" // {enable = false;};};
  # authentication = "proxy": nginx asks oauth2-proxy first; Pangolin cannot.
  proxied = extend {yomi.web.at.web-fixture = fixture "nginx" // {authentication = "proxy";};};
  proxiedOverPangolin = extend {yomi.web.at.web-fixture = fixture "pangolin" // {authentication = "proxy";};};
  signsIn = c: name: lib.hasInfix "auth_request /oauth2/auth;" (c.services.nginx.virtualHosts.${c.yomi.web.at.${name}.host}.extraConfig or "");
  checks = [
    (valid nginx && nginx.yomi.nginx.at.web-fixture.port == 19250 && !(nginx.yomi.expose.at ? web-fixture))
    (valid pangolin && pangolin.yomi.expose.at.web-fixture.port == 19250 && !(pangolin.yomi.nginx.at ? web-fixture))
    (!valid missingGatewayAuth)
    (valid staged
      && !(staged.yomi.expose.blueprint.public-resources ? inari-web-web-fixture)
      && preview.yomi.expose.blueprint.public-resources ? inari-web-web-fixture)
    (valid live
      && live.services.pocket-id.settings.APP_URL == "https://auth.hugo-berendi.de"
      && !live.yomi.expose.at.pocket-id.sso
      && !live.services.cloudflared.enable
      && expectedGatewayDns "auth")
    (!live.yomi.expose.at.media.sso
      && expectedGatewayDns "media")
    (lib.all (name:
      !live.yomi.expose.at.${name}.sso
      && expectedGatewayDns name) ["audiobookshelf" "request-media" "bin" "search" "ntfy" "immich-share" "cloud" "office"])
    (monitoredUrls "jellyseerr" == ["https://request-media.hugo-berendi.de"])
    (monitoredUrls "microbin" == ["https://bin.hugo-berendi.de"])
    (monitoredUrls "searxng" == ["https://search.hugo-berendi.de"])
    (monitoredUrls "nextcloud"
      == ["https://cloud.hugo-berendi.de"]
      && live.services.nextcloud.hostName == "cloud.hugo-berendi.de"
      && live.services.collabora-online.settings.server_name == "office.hugo-berendi.de")
    (monitoredUrls "immich-share"
      == ["https://immich-share.hugo-berendi.de"]
      && live.services.immich.settings.server.externalDomain == "https://immich-share.hugo-berendi.de"
      && !(live.yomi.expose.at ? immich))
    (!(disabled.yomi.expose.at ? web-fixture))
    (valid proxied && signsIn proxied "web-fixture" && !signsIn nginx "web-fixture")
    (!valid proxiedOverPangolin)
  ];
in
  assert lib.all (result: result) checks;
    pkgs.writeText "web-endpoint-checks" "Passed transport selection, explicit auth, proxy sign-in, staged activation and gateway DNS checks."
