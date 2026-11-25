{
  config,
  lib,
  pkgs,
  ...
}: let
  # The ntfy token wires itself up once it is in secrets.yaml; until then the
  # alert spine runs without one and ntfy answers 403. See ../../lib/has-secret.nix.
  hasNtfyToken = import ../../lib/has-secret.nix "n8n_ntfy_token";
in {
  imports = [./workflows.nix];

  config = {
    # {{{ Ports
    yomi.ports = {
      n8n = 8438;
      n8n-alert-router = 8508;
    };
    # }}}
    # The editor has its own login; webhooks are refused at nginx below.
    yomi.web.at.n8n = {
      transport = "nginx";
      authentication = "application";
      monitor.enable = true;
      # n8n listens on IPv4 loopback only (N8N_LISTEN_ADDRESS below), and
      # "localhost" would have nginx try ::1 first on every request.
      proxyAddress = "127.0.0.1";
    };
    # Webhooks have no authentication of their own, and every caller is on
    # this host (Grafana, the workflows, the execution monitor) and talks to
    # 127.0.0.1:8438 directly. The hostname, and the login-protected tunnel
    # name that proxies to it, serve the editor only. Forms and MCP triggers
    # are unauthenticated the same way. Case-insensitive on purpose: n8n's
    # router matches /WEBHOOK/... too, and a plain prefix location would not.
    services.nginx.virtualHosts.${config.yomi.web.at.n8n.host}.locations."~* ^/(webhook|webhook-test|webhook-waiting|form|form-test|form-waiting|mcp|mcp-test)(/|$)".return = "404";

    # {{{ Service API keys for workflows
    # The *arr values are the same secrets their services consume, so a
    # template avoids a second copy to rotate. Immich gets a dedicated key
    # limited to asset reads and album management.
    sops.secrets = lib.genAttrs (
      [
        "n8n_webuntis_env"
        "n8n_immich_api_key"
        "n8n_paperless_api_token"
        "n8n_mealie_api_token"
        "n8n_jellyseerr_api_key"
        "sonarr_api_key"
        "radarr_api_key"
      ]
      ++ lib.optional hasNtfyToken "n8n_ntfy_token"
    ) (_: {sopsFile = ../../secrets.yaml;});

    # No NTFY_TOKEN here: only the alert router and the execution monitor
    # publish to ntfy, and both read n8n-alert-router.env. Every Code node can
    # read this file's values (see N8N_BLOCK_ENV_ACCESS_IN_NODE).
    sops.templates."n8n-services.env".content = ''
      IMMICH_API_KEY=${config.sops.placeholder.n8n_immich_api_key}
      PAPERLESS_API_TOKEN=${config.sops.placeholder.n8n_paperless_api_token}
      MEALIE_API_TOKEN=${config.sops.placeholder.n8n_mealie_api_token}
      JELLYSEERR_API_KEY=${config.sops.placeholder.n8n_jellyseerr_api_key}
      SONARR_API_KEY=${config.sops.placeholder.sonarr_api_key}
      RADARR_API_KEY=${config.sops.placeholder.radarr_api_key}
    '';
    sops.templates."n8n-alert-router.env".content =
      lib.optionalString hasNtfyToken "NTFY_TOKEN=${config.sops.placeholder.n8n_ntfy_token}\n";
    # }}}

    services.n8n = {
      enable = true;
      environment = {
        DIABETES_URL = "http://127.0.0.1:${toString config.yomi.ports.diabetes}";
        WEBHOOK_URL = config.yomi.web.at.n8n.url;
        N8N_PORT = toString config.yomi.web.at.n8n.port;
        N8N_HOST = "127.0.0.1";
        # N8N_HOST only names the host in generated URLs; the listener binds
        # to every address unless told otherwise. The Docker bridges are
        # accepted without a port filter, so their clients could otherwise
        # post to the unauthenticated webhooks.
        N8N_LISTEN_ADDRESS = "127.0.0.1";
        N8N_EDITOR_BASE_URL = config.yomi.web.at.n8n.url;
        N8N_TEMPLATES_ENABLED = toString true;
        N8N_AI_ENABLED = toString true;
        # inari has no IPv6 default route, but Node 17+ returns DNS results in
        # raw order (AAAA before A for migadu.com), so nodemailer/undici pick
        # the unreachable v6 address first and fail with ENETUNREACH. Force
        # IPv4-first resolution for the whole process instead of per-request.
        NODE_OPTIONS = "--dns-result-order=ipv4first";

        # Code nodes reach environment variables through `$env`, and n8n
        # blocks that by default: createEnvProviderState() treats anything
        # other than the exact string "false" as blocked, so the workflows see
        # "access to env vars denied" rather than an empty value.
        #
        # lib.boolToString, not toString: `toString false` is "" in Nix, which
        # would leave env access blocked while looking like it had been turned
        # off.
        #
        # The cost is real and worth stating: this hands every Code node the
        # whole process environment, which here includes the webuntis
        # credentials and the *arr API keys. That is what the workflows need,
        # and it is what they had when they read process.env, but it does mean
        # a Code node added through the web ui can read every secret the unit
        # holds.
        N8N_BLOCK_ENV_ACCESS_IN_NODE = lib.boolToString false;

        # The inbox organizer classifies mail against the small dedicated
        # llama.cpp, not a larger general model: a 14B answered correctly and took some forty seconds
        # per mail on this CPU-only box. Not a secret, so it belongs here rather than in
        # the EnvironmentFile.
        CLASSIFIER_URL = "http://127.0.0.1:${toString config.yomi.ports.llama-cpp-classifier}/v1/chat/completions";

        # The alert spine publishes straight to ntfy on loopback rather than
        # through its public url: a notification about the tunnel being down
        # should not have to travel through the tunnel to arrive.
        NTFY_URL = "http://127.0.0.1:${toString config.yomi.ports.ntfy}";
        NTFY_TOPIC = "inari-alerts";

        # Workflows reach the spine on loopback for the same reason it reaches
        # ntfy that way, and naming it here means a workflow never has to
        # hardcode the port it happens to listen on today.
        ALERT_WEBHOOK_URL = "http://127.0.0.1:${toString config.yomi.ports.n8n}/webhook/alert";
        ALERT_ROUTER_URL = "http://127.0.0.1:${toString config.yomi.ports.n8n-alert-router}/alert";
      };
    };

    systemd.services.n8n = {
      wants = ["n8n-alert-router.service"];
      after = ["n8n-alert-router.service"];
      path = with pkgs; [
        nodejs
        git
        python3 # for native node modules
        gcc # for native node modules
        busybox
      ];

      # EnvironmentFile is read by systemd itself before the DynamicUser/
      # hardening sandbox applies, so the secret never touches the nix store or
      # a world-readable unit file -- unlike services.n8n.environment above,
      # which is a plain nix string. The webuntis-radicale workflow reads
      # these back out of process.env instead of hardcoding them, since this
      # repository is mirrored to a public forge.
      serviceConfig.EnvironmentFile = [
        config.sops.secrets.n8n_webuntis_env.path
        config.sops.templates."n8n-services.env".path
      ];
    };

    # Static workflow data is saved as whole snapshots, so overlapping n8n
    # executions lose queued alerts. One local process serializes publication
    # and persists receipts before acknowledging a webhook.
    systemd.services.n8n-alert-router = {
      description = "Durable notification queue and quiet hours";
      wantedBy = ["multi-user.target"];
      after = ["network.target" "sops-nix.service"];
      environment = {
        inherit (config.services.n8n.environment) NTFY_URL NTFY_TOPIC;
        PORT = toString config.yomi.ports.n8n-alert-router;
      };
      serviceConfig = {
        ExecStart = "${pkgs.nodejs}/bin/node ${./alert-router.cjs}";
        EnvironmentFile = config.sops.templates."n8n-alert-router.env".path;
        DynamicUser = true;
        StateDirectory = "n8n-alert-router";
        StateDirectoryMode = "0700";
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 5;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      };
    };

    # A workflow cannot report that n8n itself is down. Share its dynamic
    # account to read execution metadata, and send directly to ntfy when the
    # router heartbeat fails. Neither execution payloads nor credentials are read.
    systemd.services.n8n-execution-monitor = {
      description = "Check n8n execution outcomes and notification delivery";
      after = ["n8n.service"];
      environment = {
        inherit (config.services.n8n.environment) ALERT_WEBHOOK_URL NTFY_URL NTFY_TOPIC;
      };
      serviceConfig = {
        Type = "oneshot";
        User = "n8n";
        DynamicUser = true;
        StateDirectory = ["n8n" "n8n-monitor"];
        StateDirectoryMode = "0700";
        EnvironmentFile = config.sops.templates."n8n-alert-router.env".path;
        ExecStart = "${pkgs.python3}/bin/python ${./execution-monitor.py} --database /var/lib/n8n/.n8n/database.sqlite --editor-url ${lib.escapeShellArg config.services.n8n.environment.N8N_EDITOR_BASE_URL} --state /var/lib/n8n-monitor/notification-state.json";
        TimeoutStartSec = "2m";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        ReadOnlyPaths = ["/var/lib/n8n"];
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      };
    };
    systemd.timers.n8n-execution-monitor = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = true;
      };
    };
  };
}
