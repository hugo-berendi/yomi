# Pocket ID sign-in in front of the nginx endpoints that declare
# authentication = "proxy" (yomi.web.at). nginx asks oauth2-proxy about
# every request (auth_request) and sends a browser without a session to
# Pocket ID. The cookie stays on the endpoint's own host, so each endpoint
# signs in on its own; Pocket ID's "LAN sign-in" client lists one callback
# URL per endpoint, https://<host>/oauth2/callback.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.oauth2-proxy;
  protected = lib.filterAttrs (_: e: e.enable && e.authentication == "proxy") config.yomi.web.at;
in {
  # {{{ Ports
  yomi.ports = {
    oauth2-proxy = 8402;
  };
  # }}}
  # {{{ Secrets
  # Created on inari from the public recipients (see .sops.yaml), so they
  # live beside the service rather than in inari's secrets.yaml.
  sops.secrets = {
    oauth2_proxy_client_secret.sopsFile = ./secrets.yaml;
    oauth2_proxy_cookie_secret.sopsFile = ./secrets.yaml;
  };
  # }}}
  # {{{ Service
  services.oauth2-proxy = {
    enable = protected != {};
    provider = "oidc";
    oidcIssuerUrl = config.yomi.web.at.pocket-id.url;
    # Pocket ID's "LAN sign-in" client, limited there to the lan_sign_in
    # group, which holds only the pilot.
    clientID = "b55c6b67-d675-4789-b59c-0c82880d9fa5";
    clientSecretFile = config.sops.secrets.oauth2_proxy_client_secret.path;
    cookie.secretFile = config.sops.secrets.oauth2_proxy_cookie_secret.path;
    # A second guard behind Pocket ID's group: the services behind this
    # trust whoever gets through, and Beszel signs them in as the pilot.
    email.addresses = config.yomi.pilot.email;
    httpAddress = "http://127.0.0.1:${toString config.yomi.ports.oauth2-proxy}";
    reverseProxy = true;
    trustedProxyIP = ["127.0.0.1/32"];
    # Pocket ID remembers the consent; "force" would ask on every sign-in.
    approvalPrompt = "auto";
    extraConfig = {
      code-challenge-method = "S256";
      skip-provider-button = true;
    };
  };

  systemd.services.oauth2-proxy.serviceConfig = {
    CapabilityBoundingSet = "";
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "strict";
    RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = ["@system-service" "~@privileged"];
  };
  # }}}
  # {{{ nginx
  # A location that sets `auth_request off;` skips the sign-in, for paths
  # that carry their own credentials (Beszel's agents) or answer a health
  # check.
  services.nginx.virtualHosts = lib.mapAttrs' (_: e:
    lib.nameValuePair e.host {
      extraConfig = ''
        auth_request /oauth2/auth;
        error_page 401 = @oauth2_sign_in;
      '';
      locations = {
        "/oauth2/" = {
          proxyPass = cfg.httpAddress;
          extraConfig = ''
            auth_request off;
            proxy_set_header X-Auth-Request-Redirect $request_uri;
          '';
        };
        "= /oauth2/auth" = {
          proxyPass = cfg.httpAddress;
          extraConfig = ''
            auth_request off;
            proxy_set_header Content-Length "";
            proxy_pass_request_body off;
          '';
        };
        "@oauth2_sign_in".extraConfig = ''
          auth_request off;
          return 302 /oauth2/start?rd=$request_uri;
        '';
      };
    })
  protected;
  # }}}
}
