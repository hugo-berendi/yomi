{
  config,
  pkgs,
  ...
}: {
  programs.nixcord = {
    discord.enable = false;
    vesktop.enable = true;
    enable = true; # enable Nixcord. Also installs discord package
    config = {
      themeLinks = [
        # or use an online theme
        "https://raw.githubusercontent.com/rose-pine/discord/main/rose-pine-moon.theme.css"
      ];
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

  # {{{ Storage
  # Clean cache older than 10 days
  systemd.user.tmpfiles.rules = [
    "d ${config.xdg.configHome}/discord/Cache/Cache_Data - - - 10d"
  ];

  satellite.persistence.at.state.apps.discord.directories = [
    "${config.xdg.configHome}/discord" # Why tf does discord store it's state here 💀
  ];
  #}}}
}
