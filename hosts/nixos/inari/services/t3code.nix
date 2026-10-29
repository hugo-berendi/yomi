{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  pilot = config.yomi.pilot.name;
  port = config.yomi.ports.t3code;
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  codex = import ../../../../home/features/cli/ai/codex-package.nix {inherit inputs pkgs;};
  # Use the pinned upstream release until llm-agents packages 0.1.2.
  opencode = import ../../../../home/features/cli/ai/opencode/package.nix {inherit inputs pkgs;};
  package = pkgs.callPackage ../../../../pkgs/t3code-release.nix {
    providerPackages = [codex agents.claude-code opencode];
    memoryServer = pkgs.callPackage ../../../../pkgs/t3code-memory.nix {};
  };
in {
  yomi.nginx.at.t3code.port = port;

  users.users.${pilot}.linger = true;

  home-manager.users.${pilot} = {config, ...}: {
    home.packages = [package];

    yomi.persistence.at.state.apps.t3code.directories = [
      "${config.home.homeDirectory}/.t3"
    ];

    systemd.user.services.t3code-web = {
      Unit = {
        Description = "T3 Code Web Server";
        After = ["network.target"];
      };
      Service = {
        Environment = [
          "PATH=${lib.makeBinPath [pkgs.git pkgs.ripgrep pkgs.nodejs]}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
          # The FHS wrapper runs in a bwrap user namespace that maps only the
          # pilot's uid, so every /nix/store file shows up as owned by nobody.
          # ~/.ssh/config is a home-manager symlink into the store, and ssh
          # refuses the default user config with "Bad owner or permissions",
          # which failed `git fetch origin` while provisioning worktrees.
          # An explicit -F skips that ownership check.
          "\"GIT_SSH_COMMAND=ssh -F ${config.home.homeDirectory}/.ssh/config\""
        ];
        ExecStart = "${lib.getExe package} serve --host 127.0.0.1 --port ${toString port} --base-dir ${config.home.homeDirectory}/.t3";
        WorkingDirectory = config.home.homeDirectory;
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
