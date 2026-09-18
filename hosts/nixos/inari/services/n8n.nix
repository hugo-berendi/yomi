{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.n8n;
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
  importScript = name: workflow:
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
      ${n8n} import:workflow --input=${workflow.source} --activeState=fromJson
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

    sops.secrets.n8n_webuntis_env.sopsFile = ../secrets.yaml;

    # {{{ Assertions
    # Read the JSON at eval time: an import without an id creates a new
    # workflow on every single start rather than updating the existing one.
    assertions =
      lib.mapAttrsToList (name: workflow: let
        parsed = builtins.fromJSON (builtins.readFile workflow.source);
      in {
        assertion = parsed ? id && parsed.id != "";
        message = ''
          yomi.n8n.workflows.${name} has no `id`, so `n8n import:workflow`
          would create a duplicate every time the service starts instead of
          updating the existing workflow. Export it from n8n rather than
          hand-writing it.
        '';
      })
      cfg.workflows;
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
      serviceConfig.EnvironmentFile = [config.sops.secrets.n8n_webuntis_env.path];

      # Leading `-` on purpose: a workflow that fails to import should leave a
      # complaint in the journal, not stop n8n from starting at all. The
      # assertion above already rejects the JSON shape that would fail here.
      serviceConfig.ExecStartPre =
        lib.mapAttrsToList (name: workflow: "-${importScript name workflow}") cfg.workflows;
    };

    # {{{ Managed workflows
    yomi.n8n.workflows.webuntis-radicale.source = ./n8n/workflows/webuntis-radicale.json;
    # Seed only: it references an SMTP credential ("Migadu (no-reply)") that
    # must be created once in the web ui before the send-email node will run,
    # same as "Radicale" for webuntis-radicale above.
    yomi.n8n.workflows.health-monitor = {
      source = ./n8n/workflows/health-monitor.json;
      enforce = false;
    };
    # }}}
  };
}
