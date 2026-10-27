{
  config,
  lib,
  ...
}: {
  options.yomi.machine = {
    graphical = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Whether this host runs a graphical desktop.";
    };

    audio = lib.mkOption {
      type = lib.types.bool;
      default = config.yomi.machine.graphical;
      description = "Enable PipeWire audio independently of the desktop.";
    };
    bluetooth = lib.mkOption {
      type = lib.types.bool;
      default = config.yomi.machine.graphical;
      description = "Enable Bluetooth independently of the desktop.";
    };

    interactible = lib.mkOption {
      default = config.yomi.machine.graphical;
      type = lib.types.bool;
      description = ''
        Whether this machine is physically interactible with. Enables things
        like specific keyboard layouts.

        This differs from the "graphical" flag, since machines like my home
        server(s) need to some times be manually typed on, even though they
        do not offer any visuals besides the stock tty.
      '';
    };

    gaming = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "
        Whether this machine will be used to play games.
      ";
    };
  };

  config.assertions = [
    {
      assertion = !config.yomi.machine.gaming || config.yomi.machine.graphical;
      message = "yomi.machine.gaming requires yomi.machine.graphical.";
    }
  ];
}
