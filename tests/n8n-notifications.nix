{pkgs}: let
  workflows = ../hosts/nixos/inari/services/n8n/workflows;
  # The router requires its triage module beside it, as in the service.
  n8n = pkgs.runCommand "alert-router" {} ''
    mkdir $out
    cp ${../hosts/nixos/inari/services/n8n/alert-router.cjs} $out/alert-router.cjs
    cp ${../hosts/nixos/inari/services/n8n/alert-triage.cjs} $out/alert-triage.cjs
  '';
in
  pkgs.runCommand "n8n-notification-tests" {nativeBuildInputs = [pkgs.nodejs pkgs.python3];} ''
    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONTZPATH=${pkgs.tzdata}/share/zoneinfo
    node ${./n8n-alert-router.cjs} ${n8n}/alert-router.cjs
    node ${./n8n-alert-router-http.cjs} ${n8n}/alert-router.cjs
    node ${./n8n-alert-triage.cjs} ${n8n}/alert-router.cjs ${n8n}/alert-triage.cjs
    node ${./n8n-disk-recovery.cjs} ${workflows}/disk-health.json
    node ${./n8n-paperless-reminders.cjs} ${workflows}/paperless-dates.json
    node ${./n8n-webuntis-write.cjs} ${workflows}/webuntis-radicale.json
    node ${./n8n-monitors.cjs} ${workflows}
    node ${./n8n-output-policy.cjs} ${workflows}
    export N8N_EXECUTION_MONITOR=${../hosts/nixos/inari/services/n8n/execution-monitor.py}
    python ${./test_n8n_execution_monitor.py}
    export MONITORING_WATCHDOG=${../hosts/nixos/inari/services/alerting/watchdog.py}
    python ${./test_monitoring_watchdog.py}
    touch "$out"
  ''
