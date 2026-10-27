{pkgs}: let
  workflows = ../hosts/nixos/inari/services/n8n/workflows;
in
  pkgs.runCommand "n8n-notification-tests" {nativeBuildInputs = [pkgs.nodejs pkgs.python3];} ''
    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONTZPATH=${pkgs.tzdata}/share/zoneinfo
    node ${./n8n-alert-router.cjs} ${../hosts/nixos/inari/services/n8n/alert-router.cjs}
    node ${./n8n-alert-router-http.cjs} ${../hosts/nixos/inari/services/n8n/alert-router.cjs}
    node ${./n8n-disk-recovery.cjs} ${workflows}/disk-health.json
    node ${./n8n-webuntis-write.cjs} ${workflows}/webuntis-radicale.json
    node ${./n8n-monitors.cjs} ${workflows}
    node ${./n8n-output-policy.cjs} ${workflows}
    export N8N_EXECUTION_MONITOR=${../hosts/nixos/inari/services/n8n/execution-monitor.py}
    python ${./test_n8n_execution_monitor.py}
    touch "$out"
  ''
