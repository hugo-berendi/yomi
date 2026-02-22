{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.machine.graphical;
in {
  config = lib.mkIf cfg {
    services.greetd = {
      enable = true;
      useTextGreeter = false;
    };

    programs.regreet = {
      enable = true;
      settings.appearance.greeting_msg = "Welcome to ${config.networking.hostName}";
    };

    stylix.targets.regreet.enable = true;
  };
}
