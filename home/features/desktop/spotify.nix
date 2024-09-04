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

    # theme = config.satellite.theming.get themeMap;
    # colorScheme = config.satellite.theming.get colorschemeMap;

    enabledExtensions = with spicePkgs.extensions; [
      fullAppDisplayMod
      shuffle # Working shuffle
      keyboardShortcut
      skipStats # Track my skips
      listPlaylistsWithSong # Adds button to show playlists which contain a song
      playlistIntersection # Shows stuff that's in two different playlists
      fullAlbumDate
      bookmark
      trashbin
      groupSession
      wikify # Shows an artist's wikipedia entry
      songStats
      showQueueDuration
      # REASON: broken
      # https://github.com/the-argus/spicetify-nix/issues/50
      # genre
      adblock
      savePlaylists # Adds a button to duplicate playlists
    ];
  };

  # {{{ Persistence
  satellite.persistence.at.state.apps.spotify.directories = [
    "${config.xdg.configHome}/spotify"
  ];

  satellite.persistence.at.cache.apps.spotify.directories = [
    "${config.xdg.cacheHome}/spotify"
  ];
  # }}}
}
