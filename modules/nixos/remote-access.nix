# Browser access to a few tailnet-only services from a device that may not run
# Tailscale (the work laptop: no admin rights, and VPN software is against the
# employer's policy, which rules out Tailscale inside WSL as well).
#
# Each listed yomi.nginx.at endpoint gets a second hostname on the Cloudflare
# tunnel, `<name>-<suffix>.<domain>`. nginx serves those names on a loopback
# port only cloudflared talks to, and every request has to pass oauth2-proxy
# against Pocket ID before it is forwarded to the service's ordinary internal
# vhost. Going through the internal vhost, with its own Host header, means the
# application sees exactly the request it gets on the tailnet: Grafana's
# root_url, n8n's and opencode's origin checks and Homepage's allowed hosts
# need no second configuration. Redirects and the Origin header are rewritten
# between the two names.
#
# The protection does not depend on anything configured in the Cloudflare
# dashboard: without a valid oauth2-proxy session nginx answers 307 to the
# login, and a Host that is not one of the listed names gets 444.
{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.remoteAccess;
  oauth2 = "http://127.0.0.1:${toString config.yomi.ports.oauth2-proxy}";
  listen = [
    {
      addr = "127.0.0.1";
      port = config.yomi.ports.remote-access;
    }
  ];

  externalHost = name: config.yomi.cloudflared.at."remote-${name}".host;
  internalHost = name: config.yomi.nginx.at.${name}.host;

  # The whole server body is one string so tests/options.nix can run it under
  # a real nginx without the rest of the host's configuration.
  serverConfig = name: let
    external = externalHost name;
    internal = internalHost name;
  in ''
    auth_request /oauth2/auth;
    error_page 401 = @remote_login;

    location = /oauth2/auth {
      internal;
      auth_request off;
      proxy_pass ${oauth2}/oauth2/auth;
      proxy_pass_request_body off;
      proxy_set_header Content-Length "";
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-Proto https;
      proxy_set_header X-Forwarded-Host $host;
      proxy_set_header X-Forwarded-Uri $request_uri;
    }

    location /oauth2/ {
      auth_request off;
      proxy_pass ${oauth2};
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-Proto https;
      proxy_set_header X-Forwarded-Host $host;
    }

    location @remote_login {
      auth_request off;
      return 307 https://$host/oauth2/start?rd=$request_uri;
    }

    location / {
      # Applications that check Origin against their own name (n8n's push
      # connection, opencode's websocket) would reject the external one.
      set $remote_origin "";
      if ($http_origin = "https://${external}") {
        set $remote_origin "https://${internal}";
      }

      proxy_pass ${cfg.upstream};
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection $connection_upgrade;
      proxy_set_header Host ${internal};
      proxy_set_header Origin $remote_origin;
      # Loopback hop to this host's own nginx. Verification is left off so an
      # expired or renewing certificate does not take the remote path down
      # separately from the internal one.
      proxy_ssl_server_name on;
      proxy_ssl_name ${internal};
      proxy_redirect https://${internal}/ https://${external}/;
    }
  '';
in {
  options.yomi.remoteAccess = {
    enable = lib.mkEnableOption "Pocket ID protected tunnel hostnames for selected internal services";

    endpoints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["grafana" "status"];
      description = "Names of `yomi.nginx.at` entries to publish under a second, login-protected hostname.";
    };

    suffix = lib.mkOption {
      type = lib.types.str;
      default = "remote";
      description = ''
        Appended to each endpoint's DNS name. One label, so Cloudflare's
        universal certificate for `*.<domain>` still covers it.
      '';
    };

    issuerUrl = lib.mkOption {
      type = lib.types.str;
      description = "OIDC issuer (Pocket ID).";
    };

    allowedEmails = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [config.yomi.pilot.email];
      defaultText = lib.literalExpression "[config.yomi.pilot.email]";
      description = "Pocket ID accounts allowed through. Any other account is refused after login.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        sops file holding remote_access_client_id, remote_access_client_secret
        and remote_access_cookie_secret.
      '';
    };

    upstream = lib.mkOption {
      type = lib.types.str;
      default = "https://127.0.0.1:443";
      description = "Where authenticated requests go: this host's internal nginx. Overridden by tests.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (name: config.yomi.nginx.at ? ${name} && config.yomi.nginx.at.${name}.enable) cfg.endpoints;
        message = "yomi.remoteAccess.endpoints must name enabled yomi.nginx.at entries.";
      }
      {
        assertion = cfg.allowedEmails != [];
        message = "yomi.remoteAccess.allowedEmails must not be empty.";
      }
    ];

    # {{{ Secrets
    sops.secrets = lib.genAttrs ["remote_access_client_id" "remote_access_client_secret" "remote_access_cookie_secret"] (_: {
      inherit (cfg) sopsFile;
    });
    sops.templates."oauth2-proxy-remote.env".content = ''
      OAUTH2_PROXY_CLIENT_ID=${config.sops.placeholder.remote_access_client_id}
    '';
    # }}}

    # {{{ oauth2-proxy
    services.oauth2-proxy = {
      enable = true;
      provider = "oidc";
      oidcIssuerUrl = cfg.issuerUrl;
      keyFile = config.sops.templates."oauth2-proxy-remote.env".path;
      clientSecretFile = config.sops.secrets.remote_access_client_secret.path;
      httpAddress = oauth2;
      reverseProxy = true;
      trustedProxyIP = ["127.0.0.1"];
      approvalPrompt = "auto";
      # nginx asks /oauth2/auth and proxies the application itself; oauth2-proxy
      # never forwards a request anywhere.
      upstream = ["static://202"];
      # email.domains stays empty: any domain there would let every account in
      # that domain past the address list.
      email.addresses = lib.concatLines cfg.allowedEmails;
      cookie = {
        secretFile = config.sops.secrets.remote_access_cookie_secret.path;
        # Host-only cookies. A `.<domain>` cookie would also be sent to every
        # public service on the tunnel.
        domain = null;
        # The work laptop is not ours; keep a stolen session short-lived.
        expire = "12h0m0s";
      };
      extraConfig = {
        code-challenge-method = "S256";
        skip-provider-button = true;
        provider-display-name = "Pocket ID";
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
    };
    # }}}

    # {{{ Tunnel hostnames and nginx
    yomi.cloudflared.at = lib.listToAttrs (map (name:
      lib.nameValuePair "remote-${name}" {
        port = config.yomi.ports.remote-access;
        proxyAddress = "127.0.0.1";
        subdomain = "${config.yomi.nginx.at.${name}.dns.name}-${cfg.suffix}";
      })
    cfg.endpoints);

    services.nginx.virtualHosts =
      {
        remote-default = {
          inherit listen;
          default = true;
          serverName = "_";
          extraConfig = "return 444;";
        };
      }
      // lib.listToAttrs (map (name:
        lib.nameValuePair "remote-${name}" {
          inherit listen;
          serverName = externalHost name;
          extraConfig = serverConfig name;
        })
      cfg.endpoints);
    # }}}
  };
}
