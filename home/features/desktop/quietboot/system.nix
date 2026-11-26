{
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.yomi.machine.graphical {
    boot.plymouth.enable = true;
    stylix.targets.plymouth.enable = true;

    console = {
      useXkbConfig = true;
      earlySetup = false;
    };

    boot = {
      kernelParams = [
        "quiet"
        "loglevel=3"
        "systemd.show_status=auto"
        "udev.log_level=3"
        "rd.udev.log_level=3"
        "vt.global_cursor_default=0"
      ];
      consoleLogLevel = lib.mkDefault 0;
      initrd.verbose = false;
    };
  };
}
