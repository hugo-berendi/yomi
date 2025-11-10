{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.greetd;
  current_wm = lib.getExe config.programs.hyprland.package;
in {
  options.yomi.greetd = {
    enable = lib.mkEnableOption "yomi's greetd integration";
  };

  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
      vt = 1;
      settings = {
        default_session = {
          command = ''
            ${lib.getExe pkgs.greetd.tuigreet} \
              -c ${current_wm} \
              -g " (.>_>.) Welcome to ${config.networking.hostName}! (.<_<.)" \
              --user-menu \
              --remember \
              --asterisks \
              --theme border=magenta;text=white;prompt=white;time=white;action=white;button=magenta;container=black;input=white \
          '';
          user = config.users.users.pilot.name;
        };
      };
    };
  };
}
