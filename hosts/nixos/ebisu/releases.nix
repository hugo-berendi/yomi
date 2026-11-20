{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.releases;
  # Exact public paths; the signature always sits beside its manifest.
  files = ["release.json" "release.json.sig"];
  host = "${cfg.subdomain}.${cfg.domain}";
  paths = lib.concatMap (h: map (f: "/${h}/${f}") files) cfg.hosts;
  pathRule = lib.concatMapStringsSep " || " (p: "Path(`${p}`)") paths;
  responderService = "yomi-releases";
  nameRegex = "[a-z0-9]([a-z0-9-]*[a-z0-9])?";
in {
  # {{{ Options
  # Publishes CI-signed manifests that other Yomi hosts fetch over HTTPS.
  # Off until the DNS name and the root-owned files exist on this host.
  options.yomi.releases = {
    enable = lib.mkEnableOption ''
      the public static release manifest endpoint on this gateway.
      Enable only after the DNS record resolves to the gateway and the
      manifests are provisioned under `directory`'';
    domain = lib.mkOption {
      type = lib.types.str;
      default = config.yomi.dns.domain;
      description = "Zone that holds the release endpoint.";
    };
    subdomain = lib.mkOption {
      type = lib.types.strMatching nameRegex;
      default = "releases";
      description = "Label under `domain` that serves the manifests.";
    };
    hosts = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching nameRegex);
      default = ["inari"];
      description = "Yomi hosts whose `release.json` and `release.json.sig` are published at `/<host>/`.";
    };
    directory = lib.mkOption {
      type = lib.types.strMatching "/[^\n]*";
      default = "/var/lib/yomi-releases";
      description = ''
        Root-owned directory holding `<host>/release.json` and
        `<host>/release.json.sig`, copied in by hand or by a root-run job.
        It must never be a path under /nix/store.
      '';
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8522;
      description = ''
        Loopback port for the static responder, behind Traefik. Not in
        yomi.ports, because that registry is consumed by the home fleet;
        8522 is unused there and Ebisu's public ports are 80, 443, 21820
        and 51820.
      '';
    };
  };
  # }}}

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.hosts != [] && !(lib.hasPrefix "/nix/store/" cfg.directory);
        message = "yomi.releases needs at least one published host and a directory outside /nix/store.";
      }
    ];

    # {{{ Static responder
    # nginx is used only for its exact-location matching. It listens on
    # loopback and returns 404 for every other path.
    services.nginx = {
      enable = true;
      virtualHosts.${host} = {
        listen = [
          {
            addr = "127.0.0.1";
            inherit (cfg) port;
          }
        ];
        locations =
          lib.listToAttrs (lib.concatMap (h:
            map (f:
              lib.nameValuePair "= /${h}/${f}" {
                alias = "${cfg.directory}/${h}/${f}";
                extraConfig = ''
                  limit_except GET HEAD { deny all; }
                  default_type ${
                    if f == "release.json"
                    then "application/json"
                    else "text/plain"
                  };
                  add_header Cache-Control "no-cache" always;
                  add_header X-Content-Type-Options "nosniff" always;
                '';
              })
            files)
          cfg.hosts)
          // {
            "/" = {
              return = "404";
            };
          };
        extraConfig = ''
          autoindex off;
        '';
      };
    };
    # z only adjusts existing files: a missing manifest stays missing (404)
    # instead of being created empty. Mode 0644 keeps the served copy
    # unwritable by the nginx worker.
    systemd.tmpfiles.rules =
      ["d ${cfg.directory} 0755 root root -"]
      ++ lib.concatMap (h:
        [
          "d ${cfg.directory}/${h} 0755 root root -"
        ]
        ++ map (f: "z ${cfg.directory}/${h}/${f} 0644 root root -") files)
      cfg.hosts;
    # }}}

    # {{{ Traefik route
    # Reuses the gateway's HTTP-01 Let's Encrypt resolver and its entry points.
    # Only the exact manifest paths reach the responder; everything else on
    # this host falls through to Pangolin's own routers.
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        ${responderService} = {
          entryPoints = ["websecure"];
          rule = "Host(`${host}`) && (${pathRule})";
          service = responderService;
          tls.certResolver = "letsencrypt";
        };
        "${responderService}-redirect" = {
          entryPoints = ["web"];
          rule = "Host(`${host}`) && (${pathRule})";
          middlewares = ["${responderService}-https"];
          service = responderService;
        };
      };
      middlewares."${responderService}-https".redirectScheme = {
        scheme = "https";
        permanent = true;
      };
      services.${responderService}.loadBalancer.servers = [
        {url = "http://127.0.0.1:${toString cfg.port}";}
      ];
    };
    # }}}

    # {{{ DNS
    yomi.dns.records = [
      {
        at = cfg.subdomain;
        zone = cfg.domain;
        type = "CNAME";
        value = "${config.yomi.expose.publicHost}.";
      }
    ];
    # }}}
  };
}
