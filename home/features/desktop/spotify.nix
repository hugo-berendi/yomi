{
  inputs,
  pkgs,
  config,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  colors = config.lib.stylix.colors;
in {
  # {{{ Imports
  imports = [./audio.nix];
  # }}}
  # {{{ Packages
  home.packages = [
    pkgs.spot
    pkgs.playerctl
  ];
  # }}}
  # {{{ Spicetify
  programs.spicetify = {
    enable = true;

    customColorScheme = {
      text = colors.base05;
      subtext = colors.base04;
      main = colors.base00;
      sidebar = colors.base00;
      player = colors.base00;
      card = colors.base01;
      shadow = colors.base00;
      "selected-row" = colors.base02;
      button = colors.base0D;
      "button-active" = colors.base0C;
      "button-disabled" = colors.base03;
      "tab-active" = colors.base0D;
      notification = colors.base0B;
      "notification-error" = colors.base08;
      misc = colors.base0E;
    };

    enabledExtensions = with spicePkgs.extensions; [
      adblock
      betterGenres
      bookmark
      fullAlbumDate
      fullAppDisplayMod
      groupSession
      keyboardShortcut
      listPlaylistsWithSong
      playlistIntersection
      savePlaylists
      showQueueDuration
      shuffle
      skipStats
      songStats
      trashbin
      wikify
    ];
  };
  # }}}
  # {{{ Persistence
  yomi.persistence.at.state.apps.spotify.directories = [
    "${config.xdg.configHome}/spotify"
  ];

  yomi.persistence.at.cache.apps.spotify.directories = [
    "${config.xdg.cacheHome}/spotify"
  ];
  # }}}
}
