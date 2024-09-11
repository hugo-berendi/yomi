{config, ...}: {
  programs.nixcord = {
    discord.enable = false;
    vesktop.enable = true;
    enable = true; # enable Nixcord. Also installs discord package
    config = {
      enabledThemes = ["stylix.theme.css"];
      useQuickCss = true;
      frameless = true;
      autoUpdate = false;
      transparent = true;
      plugins = {
        alwaysTrust.enable = true;
        anonymiseFileNames.enable = true;
        betterFolders.enable = true;
        betterUploadButton.enable = true;
        biggerStreamPreview.enable = true;
        clearURLs.enable = true;
        copyUserURLs.enable = true;
        customRPC = {
          enable = true;
          appID = "882206464102686740";
          appName = "NixOS";
          details = "Configuring NixOS";
        };
        dearrow.enable = true;
        fakeNitro.enable = true;
        imageLink.enable = true;
        nsfwGateBypass.enable = true;
        plainFolderIcon.enable = true;
        platformIndicators.enable = true;
        readAllNotificationsButton.enable = true;
      };
    };
    extraConfig = {
    };
  };

  # {{{ theming
  stylix.targets.vesktop.enable = true;
  # }}}

  # {{{ Storage
  # Clean cache older than 10 days
  systemd.user.tmpfiles.rules = [
    "d ${config.xdg.configHome}/discord/Cache/Cache_Data - - - 10d"
    "d ${config.xdg.configHome}/Vencord/Cache/Cache_Data - - - 10d"
    "d ${config.xdg.configHome}/vesktop/Cache/Cache_Data - - - 10d"
  ];

  yomi.persistence.at.state.apps.discord.directories = [
    "${config.xdg.configHome}/discord" # Why tf does discord store it's state here 💀
    "${config.xdg.configHome}/Vencord"
    "${config.xdg.configHome}/vesktop"
  ];
  #}}}
}
