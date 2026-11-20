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

  # {{{ Signed release consumption
  cfg = config.yomi.inari.releaseUpgrade;
  stateDir = "/var/lib/yomi-release";
  releaseConfig = pkgs.writeText "yomi-release.json" (builtins.toJSON {
    host = config.networking.hostName;
    inherit (cfg) manifestUrl substituter;
    signatureUrl = "${cfg.manifestUrl}.sig";
    allowedSigners = pkgs.writeText "yomi-release-allowed-signers" cfg.allowedSigners;
    inherit stateDir;
    inherit (builtins) storeDir;
    profile = "/nix/var/nix/profiles/system";
    currentSystem = "/run/current-system";
    readiness = "${readiness}";
  });
  release = pkgs.writeShellScriptBin "yomi-release" ''
    export PATH=${lib.makeBinPath [config.nix.package pkgs.openssh pkgs.coreutils]}:$PATH
    exec ${pkgs.python3}/bin/python3 ${../../../scripts/ops/release-upgrade.py} --config ${releaseConfig} "$@"
  '';
  hasSigner = lib.any (lib.hasPrefix ''yomi-release namespaces="yomi-release" '') (lib.splitString "\n" cfg.allowedSigners);
  # }}}
in {
  # {{{ Options
  options.yomi.inari.releaseUpgrade = {
    enable = lib.mkEnableOption ''
      applying CI-signed release manifests instead of building main locally.
      It replaces system.autoUpgrade; cut over only after a manual
      `yomi-release run` succeeded on this host'';
    manifestUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "HTTPS URL of this host's release.json; the signature is fetched from `<url>.sig`.";
    };
    allowedSigners = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        ssh-keygen allowed_signers line(s) for principal `yomi-release`, restricted
        with `namespaces="yomi-release"`. This key is the whole trust root.
      '';
    };
    substituter = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Extra binary cache holding release closures; its key must already be in nix.settings.trusted-public-keys.";
    };
    dates = lib.mkOption {
      type = lib.types.str;
      default = "04:00";
      description = "systemd OnCalendar expression for release checks.";
    };
  };
  # }}}

  config = {
    # Pulls main over anonymous HTTPS so root needs no ssh key. main only
    # receives the update PRs after `just lint`/`just check` and the update gate pass,
    # and a failed build leaves the running generation untouched.
    # `switch` rather than `boot`: t3code and its providers only change when the
    # new generation is live. A switch restarts t3code-web, which ends running turns.
    # A successful rebuild does not establish that the activated applications
    # work. Fail the upgrade job after a bounded warm-up if critical consumers
    # fail; reverting migrations automatically could destroy application data.
    systemd.services.nixos-upgrade.serviceConfig = lib.mkIf config.system.autoUpgrade.enable {
      ExecStartPost = [readiness];
      # Recovered hardware must not take main's generation: main lacks the
      # recovery-local.nix and generated.nix that yomi-recover wrote on this
      # disk. yomi-recover places the hold and a human clears it.
      ExecStartPre = ["${release}/bin/yomi-release check-hold"];
    };
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "yomi-deployment-health" ''
        exec ${readiness}
      '')
      release
    ];
    # Holds this host's accepted release sequence (replay protection) and the
    # recovery hold; both must survive the root rollback.
    environment.persistence."/persist/state".directories = lib.mkIf config.yomi.persistence.enable [
      {
        directory = stateDir;
        mode = "0700";
      }
    ];

    system.autoUpgrade = {
      enable = !cfg.enable;
      flake = "git+https://git.hugo-berendi.de/hugo-berendi/yomi.git?ref=main#inari";
      operation = "switch";
      dates = "04:00";
      randomizedDelaySec = "0";
      persistent = true;
      allowReboot = false;
    };

    # {{{ Release path (opt-in)
    assertions = lib.mkIf cfg.enable [
      {
        assertion = !config.system.autoUpgrade.enable;
        message = "yomi.inari.releaseUpgrade replaces system.autoUpgrade; both would switch inari.";
      }
      {
        assertion = lib.hasPrefix "https://" cfg.manifestUrl;
        message = "yomi.inari.releaseUpgrade.manifestUrl must be an HTTPS URL.";
      }
      {
        assertion = hasSigner;
        message = ''yomi.inari.releaseUpgrade.allowedSigners needs a `yomi-release namespaces="yomi-release" <key>` line.'';
      }
    ];
    systemd.services.yomi-release-upgrade = lib.mkIf cfg.enable {
      description = "Apply the newest signed Yomi release";
      # Switching restarts changed units; this one must survive its own activation.
      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;
      wants = ["network-online.target"];
      after = ["network-online.target"];
      environment = config.nix.envVars // {HOME = "/root";} // config.networking.proxy.envVars;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${release}/bin/yomi-release run";
        # Backstop above the script's per-step limits (about 1.7 h in total).
        TimeoutStartSec = "2h";
      };
    };
    systemd.timers.yomi-release-upgrade = lib.mkIf cfg.enable {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.dates;
        Persistent = true;
      };
    };
    # }}}
  };
}
