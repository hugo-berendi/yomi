{
  inputs,
  pkgs,
  config,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in {
  imports = [./audio.nix];
  home.packages = [
    pkgs.spot
    pkgs.playerctl
  ];

  programs.spicetify = {
    enable = true;

    # theme = config.yomi.theming.get themeMap;
    # colorScheme = config.yomi.theming.get colorschemeMap;

    enabledExtensions = with spicePkgs.extensions; [
      adblock
      betterGenres
      bookmark
      fullAlbumDate
      fullAppDisplayMod
      groupSession
      keyboardShortcut
      listPlaylistsWithSong # Adds button to show playlists which contain a song
      playlistIntersection # Shows stuff that's in two different playlists
      savePlaylists # Adds a button to duplicate playlists
      showQueueDuration
      shuffle # Working shuffle
      skipStats # Track my skips
      songStats
      trashbin
      wikify # Shows an artist's wikipedia entry
    ];
  };

  # {{{ Persistence
  yomi.persistence.at.state.apps.spotify.directories = [
    "${config.xdg.configHome}/spotify"
  ];

  yomi.persistence.at.cache.apps.spotify.directories = [
    "${config.xdg.cacheHome}/spotify"
  ];
  # }}}
}
