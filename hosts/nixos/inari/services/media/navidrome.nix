{
  config,
  lib,
  ...
}: let
  musicDir = "${config.nixarr.mediaDir}/library/music";
in {
  # {{{ Reverse proxy
  # LAN and tailnet only, like the *arrs; Subsonic apps reach it over Tailscale.
  yomi.nginx.at.music.port = config.yomi.ports.navidrome;
  # }}}
  # {{{ Service
  services.navidrome = {
    enable = true;
    settings = {
      Address = "127.0.0.1";
      Port = config.yomi.nginx.at.music.port;
      MusicFolder = musicDir;
      # The filesystem watcher picks up new downloads within seconds; the
      # hourly scan only catches what it misses.
      Scanner.Schedule = "@every 1h";
      # The Spotify sync's .m3u files are imported and kept in step on every
      # scan. Only from playlists/: album folders from Soulseek often carry
      # the uploader's own .m3u, which would turn up as a playlist each.
      AutoImportPlaylists = true;
      PlaylistsPath = "playlists";
      # Smart playlists (spotify-sync-mixes.py) are filled again at most
      # once a day, like Spotify's daily mixes. Navidrome's 5 seconds
      # reshuffled every mix on each look, and Symfonium's offline copies
      # with it.
      SmartPlaylistRefreshDelay = "24h";
      EnableInsightsCollector = false;
    };
  };

  # The module would create the music folder 0700 for navidrome alone. Here
  # the media group writes it (the Spotify sync) and Navidrome only reads.
  systemd.tmpfiles.settings.navidromeDirs.${musicDir}.d = lib.mkForce {
    mode = "2775";
    user = "root";
    group = "media";
  };
  # }}}
  # {{{ Persistence
  yomi.persistence.at.state.apps.navidrome.directories = [
    {
      directory = "/var/lib/navidrome";
      mode = "u=rwx,g=,o=";
      user = config.services.navidrome.user;
      group = config.services.navidrome.group;
    }
  ];
  # }}}
}
