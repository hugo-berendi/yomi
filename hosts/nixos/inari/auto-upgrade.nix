{
  config,
  lib,
  pkgs,
  ...
}: let
  checks = pkgs.writeText "inari-deployment-checks.json" (builtins.toJSON [
    {
      name = "nginx service";
      command = ["${config.systemd.package}/bin/systemctl" "is-active" "nginx.service"];
    }
    {
      name = "Pangolin site connector";
      command = ["${config.systemd.package}/bin/systemctl" "is-active" "newt.service"];
    }
    {
      name = "PostgreSQL query";
      command = ["${pkgs.util-linux}/bin/runuser" "-u" "postgres" "--" "${config.services.postgresql.finalPackage}/bin/psql" "-X" "-v" "ON_ERROR_STOP=1" "-d" "postgres" "-c" "SELECT 1"];
    }
    {
      name = "Grafana database";
      url = "http://127.0.0.1:${toString config.yomi.ports.grafana}/api/health";
      json.database = "ok";
    }
    {
      name = "n8n readiness";
      url = "http://127.0.0.1:${toString config.yomi.ports.n8n}/healthz";
    }
    {
      name = "Jellyfin readiness";
      url = "http://127.0.0.1:${toString config.yomi.ports.jellyfin}/health";
    }
    {
      name = "nginx HTTPS route";
      command = ["${lib.getExe pkgs.curl}" "--silent" "--show-error" "--fail" "--noproxy" "*" "--max-time" "5" "--resolve" "${config.yomi.nginx.at.grafana.host}:443:127.0.0.1" "${config.yomi.nginx.at.grafana.url}/api/health"];
    }
  ]);
  readiness = pkgs.writeShellScript "inari-deployment-health" ''
    exec ${pkgs.python3}/bin/python3 ${../../../scripts/ops/deployment-health.py} ${checks}
  '';
in {
  # Pulls main over anonymous HTTPS so root needs no ssh key. main only
  # receives the update PRs after `just lint`/`just check` and the update gate pass,
  # and a failed build leaves the running generation untouched.
  # `switch` rather than `boot`: t3code and its providers only change when the
  # new generation is live. A switch restarts t3code-web, which ends running turns.
  # A successful rebuild does not establish that the activated applications
  # work. Fail the upgrade job after a bounded warm-up if critical consumers
  # fail; reverting migrations automatically could destroy application data.
  systemd.services.nixos-upgrade.serviceConfig.ExecStartPost = [readiness];
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "yomi-deployment-health" ''
      exec ${readiness}
    '')
  ];

  system.autoUpgrade = {
    enable = true;
    flake = "git+https://git.hugo-berendi.de/hugo-berendi/yomi.git?ref=main#inari";
    operation = "switch";
    dates = "04:00";
    randomizedDelaySec = "0";
    persistent = true;
    allowReboot = false;
  };
}
