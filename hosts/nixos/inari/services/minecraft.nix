{config,pkgs,inputs,...}: {
  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

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
      jvmOpts = "-Xms2048M -Xmx2048M";

      serverProperties = {
        server-port = config.yomi.cloudflared.at.minecraft.port;
        difficulty = 2;
        gamemode = 0;
        max-players = 10;
        motd = "ClassAttack Rebooted";
        white-list = false;
      };
    };
  };

  # {{{ Networking & storage
  yomi.cloudflared.at.minecraft.port = config.yomi.ports.minecraft;

  environment.persistence."/persist/state".directories = [
    "/var/lib/${config.services.minecraft-servers.dataDir}"
  ];
  # }}}
}
