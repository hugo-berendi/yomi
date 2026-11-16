{
  pkgs,
  self,
}: let
  inherit (pkgs) lib;
  base = self.nixosConfigurations.ebisu;
  extend = module: base.extendModules {modules = [module];};
  fixture = extend {
    yomi.pangolin = {
      at = {
        web = {
          port = 8080;
          users = ["owner@example.com"];
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
          yomi.pangolin.server = {
            enable = true;
            sourceHosts = ["fixture"];
            environmentFile = "/run/secrets/pangolin.env";
          };
        }
      ];
    };
  inherit (fixture) config;
  active =
    (fixture.extendModules {
      modules = [
        {
          yomi.pangolin = {
            enable = true;
            environmentFile = "/run/secrets/newt.env";
          };
        }
      ];
    }).config;
  blueprint = config.yomi.pangolin.blueprint;
  public = blueprint.public-resources;
  private = blueprint.private-resources;
  server = (gateway fixture).config;
  rejects = configuration: lib.any (a: !a.assertion) configuration.config.assertions;
  checks = [
    {
      name = "HTTP authentication and target protocol survive blueprint generation";
      assertion = public.ebisu-web-web.auth.sso-enabled && public.ebisu-web-web.auth.sso-users == ["owner@example.com"] && !(public.ebisu-web-web.auth ? whitelist-users) && (builtins.head public.ebisu-web-web.targets).method == "http";
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
      assertion = !config.services.newt.enable && config.yomi.dns.records == [] && config.networking.firewall.allowedTCPPorts == [22] && config.networking.firewall.allowedUDPPorts == [];
    }
    {
      name = "Missing access lists are rejected";
      assertion = rejects (extend {yomi.pangolin.at.unrestricted.port = 8080;}) && rejects (extend {yomi.pangolin.private.unrestricted.destination = "127.0.0.1";});
    }
    {
      name = "Activation uses a runtime credential file and DNS bypasses the Cloudflare proxy";
      assertion = lib.all (a: a.assertion) active.assertions && active.services.newt.enable && active.systemd.services.newt.serviceConfig.EnvironmentFile == "/run/secrets/newt.env" && (builtins.head active.yomi.dns.records).enableCloudflareProxy == false && active.networking.firewall.allowedTCPPorts == [22];
    }
    {
      name = "Store credentials and misleading exit-node restrictions are rejected";
      assertion =
        rejects (extend {
          yomi.pangolin = {
            enable = true;
            environmentFile = "/nix/store/secret.env";
          };
        })
        && rejects (extend {
          yomi.pangolin.private.exit = {
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
          yomi.pangolin.tcp = {
            a.port = 25565;
            b.port = 25565;
          };
        }))
        && rejects (gateway (extend {yomi.pangolin.udp.reserved.port = 51820;}))
        && rejects (gateway (extend {yomi.pangolin.tcp.reserved.port = 3005;}));
    }
    {
      name = "Duplicate web domains and missing runtime credentials are rejected";
      assertion =
        rejects (extend {
          yomi.pangolin.at = {
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
        && rejects (extend {yomi.pangolin.enable = true;});
    }
  ];
  failures = map (check: check.name) (lib.filter (check: !check.assertion) checks);
in
  assert lib.assertMsg (failures == []) ("Pangolin regressions: " + lib.concatStringsSep ", " failures);
    pkgs.runCommand "pangolin-regressions" {} ''
      touch "$out"
    ''
