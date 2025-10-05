{config, ...}: let
  user = config.yomi.pilot.name;
  group = "syncthing";
  dataDir = "/persist/state/var/lib/syncthing";
in {
  # {{{ Service
  services.syncthing = {
    inherit user group dataDir;
    enable = true;

    openDefaultPorts = true;
    configDir = "${dataDir}/config";

    overrideDevices = true;
    overrideFolders = true;

    settings = {
      # {{{ Device ids
      devices = {
        nothing.id = "7KM7BJR-DNSYR3Q-CBAFRDC-EDFPGXS-FTY2JTK-4XDELIV-BSHBM2Y-PFOWFQJ";
        ipad.id = "WPT3LB7-UQWIEKW-V7KX4ZU-YTMDRMC-HC7NVOV-BDX4ED3-CMBU5FN-LJL4AQH";
        amaterasu.id = "OAW3CNC-YF5T6PX-E5BQUZL-XT2KPAO-53AEHLH-P3C7HFR-GY2ZII6-PBS55Q2";
      };
      # }}}

      extraOptions.options.crashReportingEnabled = false;
    };

    guiAddress = "127.0.0.1:${toString config.yomi.ports.syncthing}";
    settings.gui.insecureSkipHostcheck = true;
  };
  # }}}
  # {{{ Systemd
  systemd.services.syncthing.serviceConfig.RuntimeMaxSec = "1d";

  systemd.tmpfiles.rules = ["d ${dataDir} - ${user} ${group}"];
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = dataDir;
      user = user;
      group = group;
    }
  ];
  # }}}
}
