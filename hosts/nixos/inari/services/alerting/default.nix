{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.alerting;
  ports = config.yomi.ports;
  n8nEnv = config.services.n8n.environment;

  # The heartbeat wires itself up once its ping URL is in secrets.yaml.
  hasSecret = import ../../lib/has-secret.nix;
  hasHeartbeat = hasSecret "alert_heartbeat_url";
  hasNtfyToken = hasSecret "n8n_ntfy_token";

  systemTargets =
    lib.concatMap (job: lib.concatMap (static: static.targets) job.static_configs)
    (lib.filter (job: job.job_name == "inari-system") config.services.prometheus.scrapeConfigs);
in {
  # {{{ Options
  options.yomi.alerting.retireLegacyChannels = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Remove the notification paths that duplicate the alert router: Grafana's
      Discord and mail receivers, Gatus' per-endpoint mail and the n8n
      execution monitor's own direct ntfy fallback (the watchdog owns that
      now). Leave this off until the router and the outside heartbeat have
      been checked on the running system.
    '';
  };
  # }}}

  config = {
    warnings = lib.optional (!hasHeartbeat) "Inari has no external monitoring heartbeat. Configure alert_heartbeat_url with an independently hosted check and notification channel; local monitoring cannot report a host or uplink outage.";

    # {{{ Outside heartbeat
    sops.secrets.alert_heartbeat_url = lib.mkIf hasHeartbeat {sopsFile = ../../secrets.yaml;};
    # }}}

    # {{{ Watchdog
    # Shares nothing with the router but the loopback endpoints it checks, so
    # it still reports when the router or n8n is what failed.
    systemd.services.monitoring-watchdog = {
      description = "Check the monitoring chain and send the outside heartbeat";
      after = ["n8n-alert-router.service" "network-online.target"];
      wants = ["network-online.target"];
      environment = {
        inherit (n8nEnv) ALERT_ROUTER_URL NTFY_URL NTFY_TOPIC;
        PROMETHEUS_URL = "http://127.0.0.1:${toString ports.prometheus}";
        GRAFANA_URL = "http://127.0.0.1:${toString ports.grafana}";
        LOKI_URL = "http://127.0.0.1:${toString ports.loki}";
        GATUS_URL = "http://127.0.0.1:${toString ports.gatus}";
        N8N_URL = "http://127.0.0.1:${toString ports.n8n}";
        EXPECTED_SYSTEM_TARGETS = toString (builtins.length systemTargets);
        HEARTBEAT_URL_FILE = lib.optionalString hasHeartbeat "%d/heartbeat-url";
      };
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        StateDirectory = "monitoring-watchdog";
        StateDirectoryMode = "0700";
        EnvironmentFile = lib.optional hasNtfyToken config.sops.templates."n8n-alert-router.env".path;
        LoadCredential = lib.optional hasHeartbeat "heartbeat-url:${config.sops.secrets.alert_heartbeat_url.path}";
        ExecStart = "${pkgs.python3}/bin/python3 ${./watchdog.py} --state /var/lib/monitoring-watchdog/state.json";
        TimeoutStartSec = "2m";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        CapabilityBoundingSet = "";
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      };
    };
    systemd.timers.monitoring-watchdog = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "3m";
        OnUnitActiveSec = "2m";
        AccuracySec = "15s";
      };
    };
    # }}}

    # {{{ Legacy channels
    services.grafana.provision.alerting.contactPoints.settings = lib.mkIf cfg.retireLegacyChannels {
      contactPoints = lib.mkForce [
        {
          orgId = 1;
          name = "main";
          receivers = [
            {
              uid = "main_ntfy";
              type = "webhook";
              settings = {
                url = "http://127.0.0.1:${toString ports.n8n}/webhook/grafana-alert";
                httpMethod = "POST";
              };
            }
          ];
        }
      ];
      deleteContactPoints = lib.mkForce [
        {
          orgId = 1;
          uid = "main_email";
        }
        {
          orgId = 1;
          uid = "main_discord";
        }
        {
          orgId = 1;
          uid = "mail_email";
        }
      ];
    };
    services.grafana.provision.alerting.policies.settings = lib.mkIf cfg.retireLegacyChannels {
      policies = lib.mkForce [
        {
          orgId = 1;
          receiver = "main";
          # The router owns repeats and quiet hours; Grafana's own four-hour
          # repeat would only refresh what the router already suppresses.
          repeat_interval = "24h";
        }
      ];
    };
    systemd.services.n8n-execution-monitor.environment.DIRECT_NTFY_FALLBACK = lib.boolToString (!cfg.retireLegacyChannels);
    # }}}
  };
}
