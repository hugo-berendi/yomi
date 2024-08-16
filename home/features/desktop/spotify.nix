{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
  themeMap = lib.fix (self: {
    "Rose Pine" = spicePkgs.themes.comfy;
    "Rose Pine Moon" = spicePkgs.themes.comfy;
    "Rose Pine Dawn" = spicePkgs.themes.comfy;

    default.light = self."Rose Pine Dawn";
    default.dark = self."Rose Pine Moon";
  });

  colorschemeMap = lib.fix (self: {
    "Rose Pine" = "rose-pine";
    "Rose Pine Moon" = "rose-pine-moon";
    "Rose Pine Dawn" = "rose-pine-dawn";

    default.light = self."Rose Pine Dawn";
    default.dark = self."Rose Pine Moon";
  });
in {
  imports = [./audio.nix];
  home.packages = [
    pkgs.spot
    pkgs.playerctl
  ];

  programs.spicetify = {
    enable = true;

    spotifyPackage = pkgs.unstable.spotify;

    theme = config.satellite.theming.get themeMap;
    colorScheme = config.satellite.theming.get colorschemeMap;

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
