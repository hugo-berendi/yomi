# The options of one services.steamGameServers.<name> instance.
{lib}: {
  name,
  config,
  ...
}: {
  options = {
    enable = lib.mkEnableOption "Steam game server ${name}";

    serviceName = lib.mkOption {
      type = lib.types.str;
      default = "steam-game-server-${name}";
      description = "Systemd service name for this Steam game server";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "Steam game server ${name}";
      description = "Systemd service description";
    };

    appId = lib.mkOption {
      type = lib.types.str;
      description = "Steam app id for this server";
    };

    steamPlatform = lib.mkOption {
      type = lib.types.enum ["linux" "windows"];
      default = "windows";
      description = "Platform type passed to SteamCMD";
    };

    installDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist/data/${name}/server";
      description = "Directory where SteamCMD installs server files";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist/data/${name}/data";
      description = "Persistent data directory used by the server";
    };

    wine = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Wine that runs the server; when set, its prefix is kept in step with it";
    };

    winePrefix = lib.mkOption {
      type = lib.types.str;
      default = "${config.dataDir}/.wine";
      description = "WINEPREFIX for the server, exported when wine is set";
    };

    updateOnStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run SteamCMD app_update during preStart";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = name;
      description = "System user running the server";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = name;
      description = "System group running the server";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Environment variables for the server service";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = "Environment files loaded by systemd";
    };

    preStart = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Game-specific preStart script";
    };

    script = lib.mkOption {
      type = lib.types.lines;
      description = "Game server runtime script";
    };

    useXvfb = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to launch Xvfb before running the server";
    };

    xvfbDisplay = lib.mkOption {
      type = lib.types.str;
      default = ":0";
      description = "Display passed to Xvfb";
    };

    xvfbScreen = lib.mkOption {
      type = lib.types.str;
      default = "1024x768x16";
      description = "Screen geometry passed to Xvfb";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open configured firewall ports";
    };

    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "TCP ports to open for this server";
    };

    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "UDP ports to open for this server";
    };

    tmpfilesRules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional tmpfiles rules for this server";
    };

    restartTriggers = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [];
      description = "Restart triggers for this service";
    };

    wantedBy = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["multi-user.target"];
      description = "Systemd wantedBy targets";
    };

    after = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["network-online.target"];
      description = "Systemd after dependencies";
    };

    wants = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["network-online.target"];
      description = "Systemd wants dependencies";
    };

    serviceConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional systemd serviceConfig entries";
    };
  };
}
