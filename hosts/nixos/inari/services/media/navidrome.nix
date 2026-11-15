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
      # Playlist files written next to the music (the Spotify sync's .m3u)
      # are imported and kept in step on every scan.
      AutoImportPlaylists = true;
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
