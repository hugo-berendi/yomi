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
  service = fixture.systemd.services.n8n.serviceConfig;
  scripts = map (lib.removePrefix "-") service.ExecStartPre;
in
  # Workflow CLI startup can exceed systemd's default 90 seconds under load.
  # Bound each import separately, without timing out the entire service.
  assert (service.TimeoutStartSec or null) == "infinity";
  assert lib.all (script: lib.hasPrefix "${pkgs.coreutils}/bin/timeout --signal=KILL 3m " script) scripts;
  assert lib.all (lib.hasPrefix "-") service.ExecStartPre;
    pkgs.runCommand "yomi-n8n-import-checks" {nativeBuildInputs = [pkgs.python3 pkgs.coreutils];} ''
      python3 ${./n8n-import.py} ${lib.getExe' fixture.services.n8n.package "n8n"} ${lib.escapeShellArgs scripts}
      echo 'n8n restart import preserves runtime state and seed ownership' > "$out"
    ''
