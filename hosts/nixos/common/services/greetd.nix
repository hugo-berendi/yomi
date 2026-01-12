{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.machine.graphical;
  current_wm = lib.getExe config.programs.hyprland.package;
in {
  config = lib.mkIf cfg {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = ''
            ${lib.getExe pkgs.tuigreet} \
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
