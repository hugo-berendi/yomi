{
  config,
  lib,
  pkgs,
  inputs,
  upkgs,
  ...
}: let
  pilot = config.yomi.pilot.name;
  port = config.yomi.ports.t3code;
  # Forge CLIs t3code's Forgejo/Gitea integration looks for. tea needs 0.16+, stable has 0.14.
  forgeClis = [upkgs.forgejo-cli upkgs.tea];
  package = import ../../../../pkgs/t3code-tools.nix {inherit pkgs inputs;};
in {
  imports = [./t3code-vm ./t3code-oidc.nix ./t3code-repair.nix];
  yomi.t3codeVm = {
    enable = true;
    toolingPackage = package;
    providerInstances = {
      codex = {
        driver = "codex";
        enabled = true;
      };
      claudeAgent = {
        driver = "claudeAgent";
        enabled = true;
      };
      opencode = {
        driver = "opencode";
        enabled = true;
        config.binaryPath = "/opt/t3code-tools/bin/opencode2";
      };
      acpRegistry_copilot = {
        driver = "acpRegistry";
        enabled = true;
        config = {
          source = "local";
          commandPath = "/opt/t3code-tools/bin/copilot";
          commandArgs = ["--acp"];
        };
      };
    };
  };
  yomi.nginx.at.t3code.port = port;

  users.users.${pilot}.linger = true;

  home-manager.users.${pilot} = {config, ...}: {
    home.packages = [package] ++ forgeClis;

    yomi.persistence.at.state.apps.t3code.directories = [
      "${config.home.homeDirectory}/.t3"
      "${config.home.homeDirectory}/.local/state/t3code-vm"
    ];

    systemd.user.services.t3code-web = {
      Unit = {
        Description = "T3 Code Web Server";
        After = ["network.target"];
      };
      Service = {
        Environment = [
          "SSH_AUTH_SOCK=%t/ssh-agent"
          "PATH=${lib.makeBinPath ([pkgs.git pkgs.ripgrep pkgs.nodejs] ++ forgeClis)}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
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
