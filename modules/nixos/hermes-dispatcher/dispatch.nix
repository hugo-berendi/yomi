{
  config,
  lib,
  pkgs,
  inputs,
  state,
  skills,
  launcherSource,
  routes,
}: let
  cfg = config.yomi.hermesDispatcher;
  pilotHome = config.users.users.${cfg.user}.home;
  t3 = import ../../../pkgs/t3code-tools.nix {inherit pkgs inputs;};
  socket = "/run/ciel-dispatcher/broker.sock";
  localConfig = pkgs.writeText "ciel-local-tools.json" (builtins.toJSON {
    inherit socket;
    skills = skills.bundle;
    inherit (skills) catalog;
    memoryDirectory = "${state}/home/memory";
  });
  brokerConfig = pkgs.writeText "ciel-broker.json" (builtins.toJSON {
    inherit socket routes;
    stateDirectory = "${state}/dispatch";
    matrixAuth = "${state}/matrix-auth.json";
    matrix = {inherit (cfg.matrix) homeserver userId allowedUser;};
    baseDirectory = "${pilotHome}/.t3";
    globalInstructionFile = "${pilotHome}/.codex/AGENTS.md";
    t3 = "${t3}/bin/t3";
    node = lib.getExe pkgs.nodejs;
    rpcScript = ../../../hosts/nixos/inari/services/t3code-vm/rpc.mjs;
    baseUrl = "http://127.0.0.1:${toString config.yomi.ports.t3code}";
    publicUrl = config.yomi.nginx.at.t3code.url;
    projectIds = cfg.t3.projectIds;
    maxConcurrentTasks = cfg.t3.maxConcurrentTasks;
    selectableModels = cfg.t3.selectableModels;
    # Queued tasks read project preferences from here when they start.
    memoryDirectory = "${state}/home/memory";
    taste = import ./personality.nix;
  });
  codexConfig = (pkgs.formats.toml {}).generate "ciel-codex.toml" {
    default_permissions = ":read-only";
    approval_policy = "never";
    # Codex runs commands as `/bin/sh -lc` by default. On NixOS the login
    # profile replaces PATH with the system and per-user profiles, which drops
    # the launcher's file and pdftotext ("file: command not found" in Matrix
    # document analysis). Non-login commands inherit the launcher's PATH.
    allow_login_shell = false;
    mcp_servers.ciel = {
      command = "${pkgs.python3}/bin/python3";
      args = ["${launcherSource}/mcp_server.py" "${localConfig}"];
      startup_timeout_sec = 15;
      tool_timeout_sec = 60;
      # Matrix has no Codex approval dialog. Hugo authorized these bounded
      # operations; keep shell/filesystem approvals separate from this server.
      # ciel_task_answer cannot grant a T3 permission: T3's input-request
      # interface refuses approvals, which stay with Hugo in T3.
      tools = lib.genAttrs ["ciel_start_task" "ciel_task_reply" "ciel_stop_task" "ciel_memory_write" "ciel_task_answer" "ciel_task_solve"] (_: {
        approval_mode = "approve";
      });
    };
  };
in {
  inherit socket brokerConfig codexConfig localConfig;
  service = {
    description = "Ciel's bounded durable T3 task broker";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "home-manager-${cfg.user}.service"];
    serviceConfig = {
      User = cfg.user;
      Group = config.users.users.${cfg.user}.group;
      UMask = "0077";
      RuntimeDirectory = "ciel-dispatcher";
      RuntimeDirectoryMode = "0700";
      ExecStart = "${pkgs.python3}/bin/python3 ${launcherSource}/dispatch_service.py ${brokerConfig}";
      Environment = ["HOME=${state}/broker-home" "PATH=${lib.makeBinPath [pkgs.coreutils pkgs.git pkgs.nodejs]}"];
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "tmpfs";
      # Only the broker can mint scoped T3 sessions; the conversation profile cannot see .t3.
      BindPaths = ["${pilotHome}/.t3"];
      BindReadOnlyPaths = ["${pilotHome}/.codex/AGENTS.md"];
      ReadWritePaths = [state "${pilotHome}/.t3"];
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
      CapabilityBoundingSet = "";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
