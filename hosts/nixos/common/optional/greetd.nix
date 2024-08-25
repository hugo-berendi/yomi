{
  config,
  lib,
  pkgs,
  ...
}: {
  services.greetd = {
    enable = true;
    vt = 1;
    settings = {
      default_session = {
        command = ''
          ${lib.getExe pkgs.greetd.tuigreet} \
            -c ${lib.getExe config.programs.hyprland.package} \
            -g " (.>_>.) Welcome to ${config.networking.hostName}! (.<_<.)" \
            --remember \
            --asterisks \
            --user-menu \
            --theme border=magenta;text=white;prompt=white;time=white;action=white;button=magenta;container=black;input=white \
        '';
        user = config.users.users.pilot.name;
      };
    };
  };
}
