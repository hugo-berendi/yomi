# Workflows kept in this repository and loaded into n8n before it starts.
# n8n keeps workflows in its own database, out of sight of review; this
# module imports each listed JSON on every start (or once, without
# `enforce`), so the repository stays the source of truth.
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
  importScript = name: workflow: let
    # n8n now separates import from activation: `import:workflow
    # --activeState=fromJson` errors out ("can only be used ... in queue or
    # multi-main mode") on this single-instance deployment, even though it is
    # still documented in --help. Read the JSON's own `active` field at eval
    # time and drive the replacement `publish:workflow` command instead.
    parsed = builtins.fromJSON (builtins.readFile workflow.source);
    # Import upserts every supplied column. Exported staticData=null erased
    # deduplication cursors on each restart. Omitting the field leaves the
    # instance's runtime state intact, including when an export contains an
    # old non-null copy. New workflows start with the database's NULL default.
    definition = pkgs.writeText "n8n-workflow-${name}.json" (builtins.toJSON (builtins.removeAttrs parsed ["staticData"]));
  in
    pkgs.writeShellApplication {
      name = "n8n-import-${name}";
      text = ''
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
        ${n8n} import:workflow --input=${definition}
        ${
          if parsed.active or false
          then "${n8n} publish:workflow --id=${lib.escapeShellArg parsed.id}"
          else "${n8n} unpublish:workflow --id=${lib.escapeShellArg parsed.id}"
        }
        touch "$stamp"
      '';
    };
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
          assertion = (parsed.nodeGroups or null) != null;
          message = ''
            yomi.n8n.workflows.${name} has `nodeGroups: null`, which
            violates the NOT NULL constraint on workflow_entity.nodeGroups
            and makes `n8n import:workflow` fail with SQLITE_CONSTRAINT.

            It fails only on insert, so a workflow already in the database
            imports cleanly and the same file breaks on a fresh one -- which
            is to say it breaks during a restore, and nowhere else. The
            import step is an ExecStartPre prefixed with `-`, so
            nixos-rebuild reports success either way.

            Use `nodeGroups: []`, as every working export here does.
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

    systemd.services.n8n = {
      # Leading `-` on purpose: a workflow that fails to import should leave a
      # complaint in the journal, not stop n8n from starting at all. The
      # assertion above already rejects the JSON shape that would fail here.
      # The default 90s startup deadline killed slow imports under load and
      # restarted the entire import sequence indefinitely. Bound each script
      # instead. Kill the entire process group at the deadline: TERM can kill
      # the shell first and leave its CLI child alive after timeout exits.
      # A timeout follows the same non-fatal path as an import error.
      serviceConfig.TimeoutStartSec = "infinity";
      serviceConfig.ExecStartPre =
        lib.mapAttrsToList (name: workflow: "-${pkgs.coreutils}/bin/timeout --signal=KILL 3m ${lib.getExe (importScript name workflow)}") cfg.workflows;
    };

    # {{{ Managed workflows
    yomi.n8n.workflows.webuntis-radicale.source = ./workflows/webuntis-radicale.json;
    yomi.n8n.workflows.diabetes-weekly = {
      source = ./workflows/diabetes-weekly.json;
      enforce = true;
    };
    yomi.n8n.workflows.health-monitor.source = ./workflows/health-monitor.json;
    yomi.n8n.workflows.backup-storage.source = ./workflows/backup-storage.json;
    yomi.n8n.workflows.media-arrivals.source = ./workflows/media-arrivals.json;
    yomi.n8n.workflows.forgejo-ci.source = ./workflows/forgejo-ci.json;
    yomi.n8n.workflows.immich-location-albums.source = ./workflows/immich-location-albums.json;
    yomi.n8n.workflows.immich-maintenance.source = ./workflows/immich-maintenance.json;
    yomi.n8n.workflows.immich-trip-albums.source = ./workflows/immich-trip-albums.json;
    yomi.n8n.workflows.jellyseerr-tracker.source = ./workflows/jellyseerr-tracker.json;
    yomi.n8n.workflows.mealie-groceries.source = ./workflows/mealie-groceries.json;
    # Retired with Home Assistant. Kept registered with active = false so the
    # import unpublishes it; drop both once it is gone from n8n.
    yomi.n8n.workflows.home-assistant-anomalies.source = ./workflows/home-assistant-anomalies.json;
    yomi.n8n.workflows.paperless-dates.source = ./workflows/paperless-dates.json;
    yomi.n8n.workflows.forgejo-releases.source = ./workflows/forgejo-releases.json;
    yomi.n8n.workflows.alert-router.source = ./workflows/alert-router.json;
    yomi.n8n.workflows.disk-health.source = ./workflows/disk-health.json;
    yomi.n8n.workflows.grafana-bridge.source = ./workflows/grafana-bridge.json;
    yomi.n8n.workflows.service-status.source = ./workflows/service-status.json;
    yomi.n8n.workflows.automation-failures.source = ./workflows/automation-failures.json;
    # }}}
  };
}
