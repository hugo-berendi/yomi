# Disposable read/write round trip through the Actual bridge. Server, Node,
# API bundle and bridge script are taken from inari's evaluated units, so an
# actual-server bump that the pinned API (or the bridge) no longer works with
# fails here instead of in the nightly n8n run. The budget, password and API
# key are synthetic and live only in the build's temporary directory.
{
  pkgs,
  config,
}: let
  unit = config.systemd.services.actual-bridge;
in
  pkgs.runCommand "actual-bridge-roundtrip" {
    ACTUAL_SERVER_EXE = pkgs.lib.getExe config.services.actual.package;
    BRIDGE_EXEC = unit.serviceConfig.ExecStart;
    inherit (unit.environment) ACTUAL_API_MODULE NODE_PATH;
  } ''
    export HOME="$TMPDIR"
    node=''${BRIDGE_EXEC%% *}
    "$node" ${./actual-bridge.cjs}
    echo 'actual-bridge snapshot, categorize and bank-sync round trip passed' > "$out"
  ''
