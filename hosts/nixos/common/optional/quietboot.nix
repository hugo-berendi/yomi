{
  lib,
  pkgs,
  ...
}: {
  # {{{ Plymouth
  boot.plymouth = {
    enable = true;
    themePackages = [pkgs.plymouthThemeLone];
    theme = "lone";
  };
  # }}}
  # {{{ Console
  console = {
    useXkbConfig = true;
  };
  # }}}
  # {{{ Boot parameters
  boot = {
    kernelParams = [
      "quiet"
      "loglevel=3"
      "nowatchdog"
      "splash"
      "systemd.show_status=auto"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "vt.global_cursor_default=0"
    ];
    consoleLogLevel = lib.mkDefault 0;
    initrd.verbose = false;
  };
  # }}}
}
