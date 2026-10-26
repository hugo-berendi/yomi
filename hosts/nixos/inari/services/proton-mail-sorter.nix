{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.protonMailSorter;
  python = pkgs.python3.withPackages (p: [p.imap-tools]);
  source = builtins.path {
    path = ./proton-mail-sorter;
    name = "yomi-proton-mail-sorter";
  };
  settings = pkgs.writeText "proton-mail-sorter.json" (builtins.toJSON {
    inherit (cfg) apply maxMessages maxReadMessages markExistingRead labelExisting maxLabelMessages keepFolders bridgeHost bridgePort bridgeCertificateSha256 modelUrl usernameRef passwordRef apiTokenRef;
    bridgeCertificateFile =
      if cfg.bridgeCertificateFile == null
      then null
      else "${cfg.bridgeCertificateFile}";
    opExecutable = lib.getExe pkgs._1password-cli;
  });
in {
  # {{{ Options
  options.yomi.protonMailSorter = {
    enable = lib.mkEnableOption "automatic Proton sorting scheduled through n8n";
    apply = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Apply private plans automatically. False leaves mail and flags untouched.";
    };
    maxMessages = lib.mkOption {
      type = lib.types.ints.between 1 1000;
      default = 50;
      description = "Maximum messages per background job; unchanged dry-run verdicts are cached.";
    };
    maxReadMessages = lib.mkOption {
      type = lib.types.ints.between 1 100000;
      default = 1000;
      description = "Maximum already categorized unread messages to mark read per job, without AI.";
    };
    labelExisting = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Label mail already in category folders (Action, Steuer <year>, Alias), once each, while there is nothing new to sort.";
    };
    maxLabelMessages = lib.mkOption {
      type = lib.types.ints.between 1 1000;
      default = 50;
      description = "Maximum already filed messages to label per job; most need one model call.";
    };
    keepFolders = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[^/]+");
      default = [];
      example = ["Projekte"];
      description = "Folder names under Folders/ never deleted when empty. Every other empty folder outside the categories is removed.";
    };
    markExistingRead = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Also process categorized unread mail after each scheduled sorting job, leaving mail labelled Action unread.";
    };
    bridgeHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Private address of an already authenticated Proton Mail Bridge.";
    };
    bridgePort = lib.mkOption {
      type = lib.types.port;
      default = 1143;
      description = "Bridge STARTTLS IMAP port, not the public Proton API.";
    };
    bridgeCertificateFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Pinned public PEM of this Bridge instance; its SHA256 replaces bridgeCertificateSha256.";
    };
    bridgeCertificateSha256 = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Verified SHA256 fingerprint of this Bridge instance's TLS certificate.";
    };
    modelUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString config.yomi.ports.llama-cpp-classifier}";
      description = "Base URL of the local llama.cpp server running Qwen3.5-9B; no automatic model substitution.";
    };
    serviceAccountTokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/proton-mail-sorter-op-token";
      description = "Runtime 1Password service-account token, provisioned through sops; never a Nix store path.";
    };
    usernameRef = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "op:// reference to the Bridge username in an automation-accessible vault.";
    };
    passwordRef = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "op:// reference to the Bridge password, not the Proton account password.";
    };
    apiTokenRef = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "op:// reference to a random worker API token of at least 32 characters.";
    };
  };
  # }}}

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.bridgeCertificateFile != null || builtins.match "[0-9a-fA-F]{64}" cfg.bridgeCertificateSha256 != null;
        message = "protonMailSorter requires the verified certificate fingerprint of its Bridge instance.";
      }
      {
        assertion = lib.all (ref: lib.hasPrefix "op://" ref) [cfg.usernameRef cfg.passwordRef cfg.apiTokenRef];
        message = "protonMailSorter secrets must be 1Password references, never plaintext values.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.serviceAccountTokenFile && !(lib.hasPrefix "/nix/store/" cfg.serviceAccountTokenFile);
        message = "The 1Password bootstrap token must come from an absolute runtime credential path.";
      }
    ];

    # Bridge runs from protonmail-bridge.nix, which also sets this module up.
    # The model runs in llama-cpp-classifier.nix; this unit only calls it.
    systemd.services.proton-mail-sorter = {
      description = "Private Proton mail worker for n8n";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      environment = {
        HOME = "/var/lib/proton-mail-sorter";
        OP_CONFIG_DIR = "/var/lib/proton-mail-sorter/op";
        TZ = "Europe/Berlin";
        PYTHONTZPATH = "${pkgs.tzdata}/share/zoneinfo";
        PYTHONUNBUFFERED = "1";
      };
      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "proton-mail-sorter";
        StateDirectoryMode = "0700";
        UMask = "0077";
        LoadCredential = ["op-service-account:${cfg.serviceAccountTokenFile}"];
        ExecStart = "${python}/bin/python ${source}/worker.py --config ${settings} --port ${toString config.yomi.ports.proton-mail-sorter}";
        Restart = "on-failure";
        RestartSec = 15;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        MemoryMax = "512M";
      };
    };

    # Loopback only: no nginx, tunnel or firewall exposure is needed. The
    # runtime HTTP credential stays in n8n's encrypted credential store.
    services.n8n.environment.PROTON_SORTER_URL = "http://127.0.0.1:${toString config.yomi.ports.proton-mail-sorter}";
    yomi.n8n.workflows.proton-mail-sorter = {
      source = ./n8n/workflows/proton-mail-sorter.json;
      enforce = false;
    };
    yomi.n8n.workflows.proton-mark-read = {
      source = ./n8n/workflows/proton-mark-read.json;
      enforce = false;
    };

    system.build.proton-mail-sorter-tests = pkgs.runCommand "proton-mail-sorter-tests" {} ''
      export PYTHONDONTWRITEBYTECODE=1
      export PYTHONTZPATH=${pkgs.tzdata}/share/zoneinfo
      ${python}/bin/python -m unittest discover -s ${source} -v
      ${pkgs.nodejs}/bin/node ${./proton-mail-sorter/test-workflows.cjs} ${./n8n/workflows}
      touch "$out"
    '';
  };
}
