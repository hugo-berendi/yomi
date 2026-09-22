{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.n8n;

  # sops-install-secrets validates its manifest at build time, so naming a
  # key that does not exist in secrets.yaml fails the entire nixos-rebuild
  # -- not just this service. That is a bad trade for a notification token:
  # it means the host cannot apply any configuration at all until somebody
  # with the age key is at a keyboard.
  #
  # The key names in a sops file are plaintext (only the values are
  # encrypted), so whether it is present can be decided at eval time. The
  # token wires itself up the moment it is added, and until then the spine
  # runs without one and ntfy answers 403.
  hasNtfyToken = builtins.match ".*[[:space:]]*n8n_ntfy_token:.*" (builtins.readFile ../secrets.yaml) != null;
  n8n = lib.getExe' config.services.n8n.package "n8n";

  # {{{ Workflow import
  # n8n keeps workflows in its own sqlite database, so they are invisible to
  # this repository and to review. The cli can import them, and it upserts on
  # the JSON's `id` -- which is why a missing id is an assertion below rather
  # than a surprise duplicate on every boot.
  #
  # This runs as ExecStartPre on the n8n unit itself, not as a separate
  # service: the unit is DynamicUser with StateDirectory=n8n, so only its own
  # processes get the right uid and the same N8N_USER_FOLDER. A sibling unit
  # would land on a different dynamic uid and fight over the state directory.
  # Running before the server starts also keeps the cli off a live database.
  importScript = name: workflow: let
    # n8n now separates import from activation: `import:workflow
    # --activeState=fromJson` errors out ("can only be used ... in queue or
    # multi-main mode") on this single-instance deployment, even though it is
    # still documented in --help. Read the JSON's own `active` field at eval
    # time and drive the replacement `publish:workflow` command instead.
    parsed = builtins.fromJSON (builtins.readFile workflow.source);
  in
    pkgs.writeShellScript "n8n-import-${name}" ''
      set -euo pipefail
      stamp="$STATE_DIRECTORY/.yomi-workflow-${name}"
      ${lib.optionalString (!workflow.enforce) ''
        if [ -e "$stamp" ]; then
          echo "n8n workflow ${name}: already seeded, leaving the live copy alone"
          exit 0
        fi
      ''}
      echo "n8n workflow ${name}: importing ${
        if workflow.enforce
        then "(enforced -- overwrites edits made in the web ui)"
        else "(seed -- first time only)"
      }"
      ${n8n} import:workflow --input=${workflow.source}
      ${
        if parsed.active or false
        then "${n8n} publish:workflow --id=${lib.escapeShellArg parsed.id}"
        else "${n8n} unpublish:workflow --id=${lib.escapeShellArg parsed.id}"
      }
      touch "$stamp"
    '';
  # }}}
in {
  # {{{ Options
  options.yomi.n8n.workflows = lib.mkOption {
    default = {};
    description = ''
      Workflows to load into n8n at startup, keyed by a name used for the
      systemd unit and the seed stamp.

      Export the current state with `just n8n-export` after editing in the web
      ui, so the repository stays the source of truth.
    '';
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        source = lib.mkOption {
          type = lib.types.path;
          description = "Workflow JSON as exported by n8n. Must carry its `id`.";
        };

        enforce = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Re-import on every start, so this file wins and edits made in the
            web ui are replaced. Set false to only seed the workflow once and
            let the web ui own it afterwards -- useful while building one out.
          '';
        };
      };
    });
  };
  # }}}

  config = {
    yomi.nginx.at.n8n.port = config.yomi.ports.n8n;

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
        "n8n_home_assistant_api_token"
        "n8n_jellyseerr_api_key"
        "sonarr_api_key"
        "radarr_api_key"
        "lidarr_api_key"
        "readarr_api_key"
      ]
      ++ lib.optional hasNtfyToken "n8n_ntfy_token"
    ) (_: {sopsFile = ../secrets.yaml;});

    sops.templates."n8n-services.env".content = ''
      ${lib.optionalString hasNtfyToken "NTFY_TOKEN=${config.sops.placeholder.n8n_ntfy_token}"}
      IMMICH_API_KEY=${config.sops.placeholder.n8n_immich_api_key}
      PAPERLESS_API_TOKEN=${config.sops.placeholder.n8n_paperless_api_token}
      MEALIE_API_TOKEN=${config.sops.placeholder.n8n_mealie_api_token}
      HOME_ASSISTANT_API_TOKEN=${config.sops.placeholder.n8n_home_assistant_api_token}
      JELLYSEERR_API_KEY=${config.sops.placeholder.n8n_jellyseerr_api_key}
      SONARR_API_KEY=${config.sops.placeholder.sonarr_api_key}
      RADARR_API_KEY=${config.sops.placeholder.radarr_api_key}
      LIDARR_API_KEY=${config.sops.placeholder.lidarr_api_key}
      READARR_API_KEY=${config.sops.placeholder.readarr_api_key}
    '';
    # }}}

    # {{{ Assertions
    # Read the JSON at eval time: an import without an id creates a new
    # workflow on every single start rather than updating the existing one.
    assertions = lib.concatLists (lib.mapAttrsToList (name: workflow: let
        parsed = builtins.fromJSON (builtins.readFile workflow.source);

        # Code nodes run in n8n's JS task runner, which evaluates them in a
        # bare `vm` context holding only the helpers it injects -- no
        # `process`. It does inject Buffer, the timers, TextEncoder and an
        # allowlisted `require`, so the absence is specific rather than
        # general -- `process.env.FOO` therefore
        # throws ReferenceError at runtime, and because these workflows catch
        # their own errors it surfaces as a digest cheerfully reporting every
        # service unreachable rather than as a failure anyone notices.
        #
        # It is invisible to `nix flake check`, invisible to a Code node test
        # harness built on `new Function` (which inherits the host globals),
        # and it silently broke the webuntis sync for however long. So it is
        # an eval-time assertion: $env is the supported accessor.
        usesProcessEnv =
          lib.any (node: builtins.match ".*process\\.env.*" (node.parameters.jsCode or "") != null)
          (parsed.nodes or []);
      in [
        {
          assertion = parsed ? id && parsed.id != "";
          message = ''
            yomi.n8n.workflows.${name} has no `id`, so `n8n import:workflow`
            would create a duplicate every time the service starts instead of
            updating the existing workflow. Export it from n8n rather than
            hand-writing it.
          '';
        }
        {
          assertion = !usesProcessEnv;
          message = ''
            yomi.n8n.workflows.${name} has a Code node reading `process.env`.
            n8n runs Code nodes in a task runner whose sandbox has no
            `process`, so that throws "process is not defined" at runtime.
            Use `$env.VARIABLE` instead.
          '';
        }
      ])
      cfg.workflows);
    # }}}

    services.n8n = {
      enable = true;
      environment = {
        WEBHOOK_URL = config.yomi.nginx.at.n8n.url;
        N8N_PORT = toString config.yomi.nginx.at.n8n.port;
        N8N_HOST = "127.0.0.1";
        N8N_EDITOR_BASE_URL = config.yomi.nginx.at.n8n.url;
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
        # llama.cpp, not the 14B on ${toString config.yomi.ports.llama-cpp}:
        # the 14B answers correctly and takes some forty seconds per mail on
        # this CPU-only box. Not a secret, so it belongs here rather than in
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
      };
    };

    systemd.services.n8n = {
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

      # Leading `-` on purpose: a workflow that fails to import should leave a
      # complaint in the journal, not stop n8n from starting at all. The
      # assertion above already rejects the JSON shape that would fail here.
      serviceConfig.ExecStartPre =
        lib.mapAttrsToList (name: workflow: "-${importScript name workflow}") cfg.workflows;
    };

    # {{{ Managed workflows
    yomi.n8n.workflows.webuntis-radicale.source = ./n8n/workflows/webuntis-radicale.json;
    yomi.n8n.workflows.health-monitor.source = ./n8n/workflows/health-monitor.json;
    yomi.n8n.workflows.backup-storage.source = ./n8n/workflows/backup-storage.json;
    yomi.n8n.workflows.media-arrivals.source = ./n8n/workflows/media-arrivals.json;
    yomi.n8n.workflows.forgejo-ci.source = ./n8n/workflows/forgejo-ci.json;
    yomi.n8n.workflows.inbox-organizer.source = ./n8n/workflows/inbox-organizer.json;
    yomi.n8n.workflows.immich-location-albums.source = ./n8n/workflows/immich-location-albums.json;
    yomi.n8n.workflows.immich-maintenance.source = ./n8n/workflows/immich-maintenance.json;
    yomi.n8n.workflows.immich-trip-albums.source = ./n8n/workflows/immich-trip-albums.json;
    yomi.n8n.workflows.jellyseerr-tracker.source = ./n8n/workflows/jellyseerr-tracker.json;
    yomi.n8n.workflows.mealie-groceries.source = ./n8n/workflows/mealie-groceries.json;
    yomi.n8n.workflows.home-assistant-anomalies.source = ./n8n/workflows/home-assistant-anomalies.json;
    yomi.n8n.workflows.paperless-dates.source = ./n8n/workflows/paperless-dates.json;
    yomi.n8n.workflows.forgejo-releases.source = ./n8n/workflows/forgejo-releases.json;
    yomi.n8n.workflows.alert-router.source = ./n8n/workflows/alert-router.json;
    yomi.n8n.workflows.disk-health.source = ./n8n/workflows/disk-health.json;
    yomi.n8n.workflows.grafana-bridge.source = ./n8n/workflows/grafana-bridge.json;
    # }}}
  };
}
