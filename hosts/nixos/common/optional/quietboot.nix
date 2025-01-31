{
  pkgs,
  lib,
  ...
}: {
  boot.plymouth = {
    enable = true;
    # themePackages = [pkgs.plymouthThemeLone];
    # theme = "lone";
  };
  stylix.targets.plymouth = {
    enable = true;
    logoAnimated = true;
  };

  console = {
    useXkbConfig = true;
    earlySetup = false;
  };

  boot = {
    # See https://search.nixos.org/options?show=boot.initrd.verbose&query=boot.initrd.verbose
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
}
