{
  inputs,
  pkgs,
  config,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
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
