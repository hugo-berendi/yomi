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
  package = agents.t3code.override {
    providerPackages = [agents.codex agents.claude-code agents.opencode agents.antigravity-cli];
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
