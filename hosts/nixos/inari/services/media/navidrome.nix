{
  config,
  lib,
  ...
}: let
  musicDir = "${config.nixarr.mediaDir}/library/music";
in {
  # {{{ Ports
  yomi.ports = {
    navidrome = 8519;
  };
  # }}}
  # {{{ Reverse proxy
  # The LAN and Pangolin's private alias share this Subsonic endpoint.
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
      # An album is its album artist, title and version (Deluxe and the
      # like), whatever MusicBrainz release and date each song carries.
      # The default puts those first, and songs of one album tagged on their
      # own (from Spotify, against another release) split it: on 2026-11-17
      # 14 albums showed twice or more, "All Eyez on Me" four times. Changing
      # this gave the 65 songs without a MusicBrainz track ID new IDs, and
      # with them new play counts; Kodama keeps the history. A changed PID
      # makes Navidrome rescan everything at its next start.
      PID.Album = "albumartistid,album,albumversion";
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
