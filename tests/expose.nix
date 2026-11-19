{
  pkgs,
  self,
}: let
  inherit (pkgs) lib;
  base = self.nixosConfigurations.ebisu;
  extend = module:
    base.extendModules {
      modules = [{yomi.expose.server.enable = lib.mkForce false;} module];
    };
  fixture = extend {
    yomi.expose = {
      at = {
        web = {
          port = 8080;
          protocol = "https";
          users = ["owner@example.com"];
          enableAnubis = true;
          anubis = {
            port = 9444;
            metricsPort = 9445;
          };
        };
        direct = {
          port = 8443;
          protocol = "https";
          users = ["owner@example.com"];
          healthCheck = {
            enable = true;
            path = "/health";
          };
          rules = [
            {
              match = "path";
              value = "/private-admin";
            }
          ];
          additionalTargets = [
            {
              hostname = "192.0.2.10";
              port = 8443;
              method = "https";
            }
          ];
          blockedCountries = ["CN"];
          blockedASNs = [64512];
          allowedCountries = ["DE" "AT"];
        };
        disabled = {
          enable = false;
          port = 8081;
        };
      };
      tcp.game = {
        port = 25565;
        publicPort = 25566;
      };
      udp.game.port = 25566;
      private = {
        ssh = {
          destination = "127.0.0.1";
          alias = "ssh.ebisu.internal";
          tcpPorts = [22];
          users = ["owner@example.com"];
        };
        exit = {
          mode = "exit-node";
          users = ["owner@example.com"];
        };
      };
    };
  };
  gateway = site:
    base.extendModules {
      specialArgs.outputs = self // {nixosConfigurations = self.nixosConfigurations // {fixture = site;};};
      modules = [
        {
          yomi.expose.server = {
            enable = true;
            sourceHosts = lib.mkForce ["fixture"];
          };
        }
      ];
    };
  inherit (fixture) config;
  active =
    (fixture.extendModules {
      modules = [
        {
          yomi.expose = {
            enable = true;
            environmentFile = "/run/secrets/newt.env";
          };
        }
      ];
    }).config;
  blueprint = config.yomi.expose.blueprint;
  public = blueprint.public-resources;
  private = blueprint.private-resources;
  server = (gateway fixture).config;
  rejects = configuration: lib.any (a: !a.assertion) configuration.config.assertions;
  checks = [
    {
      name = "Matrix federation is worldwide and client requests keep the EU policy";
      assertion = let
        inari = self.nixosConfigurations.inari.config;
        resource = inari.yomi.expose.blueprint.public-resources.inari-web-matrix;
      in
        !resource.auth.sso-enabled
        && map (rule: [rule.action rule.match rule.value]) resource.rules
        == [
          ["pass" "path" "/.well-known/matrix/server"]
          ["pass" "path" "/_matrix/federation/*"]
          ["pass" "path" "/_matrix/key/*"]
        ]
        ++ map (country: ["pass" "country" country]) inari.yomi.expose.allowedCountries
        ++ [["deny" "cidr" "0.0.0.0/0"] ["deny" "cidr" "::/0"]];
    }
    {
      name = "Country allowlists retain authentication and end in IPv4/IPv6 deny-all rules";
      assertion = let
        rules = public.ebisu-web-direct.rules;
        last = lib.last rules;
        countryPass = lib.filter (r: r.action == "pass" && r.match == "country") rules;
      in
        map (r: r.value) countryPass == ["DE" "AT"] && last.action == "deny" && last.match == "cidr" && last.value == "::/0" && (builtins.elemAt rules (builtins.length rules - 2)).value == "0.0.0.0/0" && !lib.any (r: r.action == "allow") rules && lib.all (r: r.priority < last.priority) countryPass;
    }
    {
      name = "Authentication budgets and session lifetime are bounded, access logs omit URL paths and credentials";
      assertion = server.services.pangolin.settings.server.dashboard_session_length_hours == 12 && server.services.pangolin.settings.server.resource_session_length_hours == 24 && server.services.pangolin.settings.rate_limits.auth.max_requests == 20 && server.services.traefik.staticConfigOptions.accessLog.fields.defaultMode == "drop" && !(server.services.traefik.staticConfigOptions.accessLog.fields.names ? RequestPath);
    }
    {
      name = "Authentication bypass and extra targets behind a single Anubis instance are rejected";
      assertion =
        rejects (extend {
          yomi.expose.at.test = {
            port = 8080;
            users = ["owner@example.com"];
            rules = [
              {
                action = "allow";
                match = "path";
                value = "/";
              }
            ];
          };
        })
        && rejects (extend {
          yomi.expose.at.test = {
            port = 8080;
            users = ["owner@example.com"];
            enableAnubis = true;
            additionalTargets = [
              {
                hostname = "192.0.2.10";
                port = 8080;
              }
            ];
          };
        });
    }
    {
      name = "Health checks probe the backend and additional targets retain transport settings";
      assertion = (builtins.head public.ebisu-web-direct.targets).healthcheck.path == "/health" && (builtins.head public.ebisu-web-direct.targets).healthcheck.hostname == "localhost" && builtins.length public.ebisu-web-direct.targets == 2 && (builtins.elemAt public.ebisu-web-direct.targets 1).hostname == "192.0.2.10" && (builtins.head public.ebisu-web-direct.rules).action == "deny" && (builtins.head public.ebisu-web-direct.rules).match == "country" && (builtins.elemAt public.ebisu-web-direct.rules 1).value == "AS64512";
    }
    {
      name = "HTTP authentication and target protocol survive blueprint generation";
      assertion = public.ebisu-web-web.auth.sso-enabled && public.ebisu-web-web.auth.sso-users == ["owner@example.com"] && !(public.ebisu-web-web.auth ? whitelist-users) && (builtins.head public.ebisu-web-web.targets).method == "http";
    }
    {
      name = "Anubis is inserted only on activation and its listeners stay private";
      assertion =
        config.services.anubis.instances
        == {}
        && (builtins.head public.ebisu-web-web.targets).port == 9444
        && active.services.anubis.instances.expose-web.settings.BIND == "127.0.0.1:9444"
        && active.services.anubis.instances.expose-web.settings.TARGET == "https://localhost:8080"
        && active.services.anubis.instances.expose-web.settings.USE_REMOTE_ADDRESS == false
        && active.yomi.ports.expose-anubis-web == 9444
        && !lib.elem 9444 active.networking.firewall.allowedTCPPorts
        && !lib.elem 9445 active.networking.firewall.allowedTCPPorts
        && builtins.removeAttrs (builtins.head public.ebisu-web-direct.targets) ["healthcheck"]
        == {
          hostname = "localhost";
          port = 8443;
          method = "https";
        }
        && builtins.attrNames active.services.anubis.instances == ["expose-web"];
    }
    {
      name = "Gateway HTTPS entrypoint applies flood limits before resource and dashboard routers";
      assertion = server.services.traefik.staticConfigOptions.entryPoints.websecure.http.middlewares == ["expose-rate-limit@file" "expose-inflight-ip@file" "expose-inflight-host@file"] && server.services.traefik.dynamicConfigOptions.http.middlewares.expose-rate-limit.rateLimit.sourceCriterion.ipStrategy == {ipv6Subnet = 64;} && server.services.traefik.dynamicConfigOptions.http.middlewares.expose-inflight-host.inFlightReq.sourceCriterion.requestHost && !server.services.traefik.staticConfigOptions.entryPoints.websecure.forwardedHeaders.insecure;
    }
    {
      name = "Disabled endpoints are absent and raw TCP/UDP do not receive HTTP fields";
      assertion = !(public ? ebisu-web-disabled) && public.ebisu-tcp-game.proxy-port == 25566 && !(public.ebisu-tcp-game ? auth) && !((builtins.head public.ebisu-udp-game.targets) ? method);
    }
    {
      name = "Private SSH grants only TCP 22 and exit nodes omit ignored port restrictions";
      assertion = private.ebisu-private-ssh.alias == "ssh.ebisu.internal" && private.ebisu-private-ssh.tcp-ports == "22" && private.ebisu-private-ssh.udp-ports == "" && private.ebisu-private-ssh.disable-icmp && !(private.ebisu-private-exit ? destination) && !(private.ebisu-private-exit ? tcp-ports);
    }
    {
      name = "Same TCP/UDP port can coexist and both reach firewall and Traefik";
      assertion = lib.all (a: a.assertion) server.assertions && lib.elem 25566 server.networking.firewall.allowedTCPPorts && lib.elem 25566 server.networking.firewall.allowedUDPPorts && server.services.traefik.staticConfigOptions.entryPoints.tcp-25566.address == ":25566/tcp" && server.services.traefik.staticConfigOptions.entryPoints.udp-25566.address == ":25566/udp";
    }
    {
      name = "A staged site creates no connector, DNS mutation or public firewall ports";
      assertion = !config.services.newt.enable && !lib.any (record: lib.elem record.at ["web" "direct" "disabled"]) config.yomi.dns.records && config.networking.firewall.allowedTCPPorts == [22] && config.networking.firewall.allowedUDPPorts == [];
    }
    {
      name = "Missing access lists are rejected";
      assertion = rejects (extend {yomi.expose.at.unrestricted.port = 8080;}) && rejects (extend {yomi.expose.private.unrestricted.destination = "127.0.0.1";});
    }
    {
      name = "Activation uses a runtime credential file and DNS bypasses the Cloudflare proxy";
      assertion = lib.all (a: a.assertion) active.assertions && active.services.newt.enable && active.systemd.services.newt.serviceConfig.EnvironmentFile == "/run/secrets/newt.env" && lib.any (record: record.at == "web" && !record.enableCloudflareProxy) active.yomi.dns.records && active.networking.firewall.allowedTCPPorts == [22];
    }
    {
      name = "Store credentials and misleading exit-node restrictions are rejected";
      assertion =
        rejects (extend {
          yomi.expose = {
            enable = true;
            environmentFile = "/nix/store/secret.env";
          };
        })
        && rejects (extend {
          yomi.expose.private.exit = {
            mode = "exit-node";
            tcpPorts = [443];
            users = ["owner@example.com"];
          };
        });
    }
    {
      name = "Duplicate raw listeners and reserved gateway ports are rejected";
      assertion =
        rejects (gateway (extend {
          yomi.expose.tcp = {
            a.port = 25565;
            b.port = 25565;
          };
        }))
        && rejects (gateway (extend {yomi.expose.udp.reserved.port = 51820;}))
        && rejects (gateway (extend {yomi.expose.tcp.reserved.port = 3005;}));
    }
    {
      name = "Duplicate web domains and missing runtime credentials are rejected";
      assertion =
        rejects (extend {
          yomi.expose.at = {
            a = {
              port = 8080;
              sso = false;
            };
            b = {
              port = 8081;
              host = "a.hugo-berendi.de";
              dns.enable = false;
              sso = false;
            };
          };
        })
        && rejects (extend {yomi.expose.enable = true;});
    }
  ];
  failures = map (check: check.name) (lib.filter (check: !check.assertion) checks);
in
  assert lib.assertMsg (failures == []) ("Pangolin regressions: " + lib.concatStringsSep ", " failures);
    pkgs.runCommand "pangolin-regressions" {} ''
      touch "$out"
    ''
