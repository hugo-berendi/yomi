{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];
  nixpkgs.overlays = [inputs.nix-minecraft.overlay];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;

    servers.classattack = {
      enable = true;
      package = pkgs.paperServers.paper-1_21_1;

      autoStart = true;
      openFirewall = true;
      restart = "always";
      enableReload = true;
      jvmOpts = "-Xms4096M -Xmx4096M";

      serverProperties = {
        server-port = config.yomi.ports.minecraft;
        difficulty = 2;
        gamemode = 0;
        max-players = 10;
        motd = "ClassAttack Rebooted";
        white-list = false;
      };
    };
  };

  # {{{ Networking & storage
  services.playit.runOverride."62c4be83-2a4e-4833-873b-1d3cb2e21414".port = config.yomi.ports.minecraft;

  environment.persistence."/persist/state".directories = [
    "/var/lib/${config.services.minecraft-servers.dataDir}"
  ];
  # }}}
}
