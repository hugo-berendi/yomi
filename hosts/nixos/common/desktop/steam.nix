{
  pkgs,
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.yomi.machine.gaming {
    assertions = [
      {
        message = "Gaming module can only be used on graphical machines";
        assertion = config.yomi.machine.graphical;
      }
    ];

    programs.gamescope = {
      enable = true;
      capSysNice = true;
      args = [
        "--backend"
        "sdl"
      ];
    };

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
      extraPackages = [
        pkgs.gamescope
        pkgs.gamemode
      ];
      extraCompatPackages = [
        pkgs.proton-ge-bin
      ];
    };
  };
}
