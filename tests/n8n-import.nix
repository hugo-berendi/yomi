{
  pkgs,
  configuration,
}: let
  inherit (pkgs) lib;
  workflow = id: staticData:
    pkgs.writeText "${id}.json" (builtins.toJSON {
      inherit id staticData;
      name = id;
      active = false;
      nodes = [
        {
          id = "manual";
          name = "Manual";
          type = "n8n-nodes-base.manualTrigger";
          typeVersion = 1;
          position = [0 0];
          parameters = {};
        }
      ];
      connections = {};
      nodeGroups = [];
      settings = {};
      tags = [];
    });
  fixture =
    (configuration.extendModules {
      modules = [
        {
          yomi.n8n.workflows = lib.mkForce {
            enforced.source = workflow "yomiEnforcedFixture" null;
            seeded = {
              source = workflow "yomiSeededFixture" {global.staleExport = true;};
              enforce = false;
            };
          };
        }
      ];
    }).config;
  scripts = map (lib.removePrefix "-") fixture.systemd.services.n8n.serviceConfig.ExecStartPre;
in
  pkgs.runCommand "yomi-n8n-import-checks" {nativeBuildInputs = [pkgs.python3 pkgs.coreutils];} ''
    python3 ${./n8n-import.py} ${lib.getExe' fixture.services.n8n.package "n8n"} ${lib.escapeShellArgs scripts}
    echo 'n8n restart import preserves runtime state and seed ownership' > "$out"
  ''
