{
  config,
  lib,
  pkgs,
  ...
}: let
  musicDir = "${config.nixarr.mediaDir}/library/music";
  stateDir = "/var/lib/spotify-sync";

  secretNames = [
    "spotify_sync_client_id"
    "spotify_sync_client_secret"
    "spotify_sync_refresh_token"
    "soulseek_username"
    "soulseek_password"
  ];
  # Same eval-time test as alerting/default.nix: a missing sops key would fail
  # the whole activation, so the sync only wires itself up once all of them
  # have been added to secrets.yaml.
  secretsYaml = builtins.readFile ../../secrets.yaml;
  hasSecrets = lib.all (name: builtins.match ".*[[:space:]]*${name}:.*" secretsYaml != null) secretNames;

  # File name inside an album folder: track number when tagged, else the
  # Soulseek file name as the last resort.
  fileFormat = "{track(. )artist( - )title|artist( - )title|sartist( - )stitle|slsk-filename}";

  # What gets synced follows the Spotify library itself (liked songs, saved
  # albums, own playlists), so adding music never means editing this file.
  # New releases of the library's artists, from Deezer.
  radar = pkgs.writers.writePython3Bin "spotify-sync-radar" {
    flakeIgnore = ["E501"];
  } (builtins.readFile ./spotify-sync-radar.py);

  sync = pkgs.writeShellApplication {
    name = "spotify-sync";
    runtimeInputs = [pkgs.sockseek radar pkgs.curl pkgs.jq pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.util-linux];
    text = builtins.readFile ./spotify-sync.sh;
  };

  # Puts library songs into the playlists where sockseek wrote #FAIL.
  resolve = pkgs.writers.writePython3Bin "spotify-sync-resolve" {
    flakeIgnore = ["E501"];
  } (builtins.readFile ./spotify-sync-resolve.py);

  # Lists the album folders that ended up without a cover.
  covers = pkgs.writers.writePython3Bin "spotify-sync-covers" {
    libraries = [pkgs.python3Packages.mutagen];
    flakeIgnore = ["E501"];
  } (builtins.readFile ./spotify-sync-covers.py);

  # Writes the smart playlists: a mix per artist and genre, and a few lists.
  mixes = pkgs.writers.writePython3Bin "spotify-sync-mixes" {
    flakeIgnore = ["E501"];
  } (builtins.readFile ./spotify-sync-mixes.py);
  # Draws their covers, and the Release Radar's.
  art = pkgs.writers.writePython3Bin "spotify-sync-art" {
    libraries = [pkgs.python3Packages.pillow pkgs.python3Packages.mutagen];
    flakeIgnore = ["E501"];
  } (builtins.replaceStrings ["@fonts@"] ["${pkgs.figtree}/share/fonts/opentype"] (builtins.readFile ./spotify-sync-art.py));
  # Artists the genre mixes leave out. Kato's 80-song Zelda lullaby album
  # is tagged House and would be half of "Electronic"; it has its own mix.
  leaveOutOfGenreMixes = ["Kato"];

  tag = pkgs.writeShellApplication {
    name = "spotify-sync-tag";
    runtimeInputs = [pkgs.beets resolve covers mixes art pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.util-linux];
    text = builtins.readFile ./spotify-sync-tag.sh;
  };

  # sockseek runs this after every finished download. It only notes the file
  # (and, for Spotify songs, the track URI); spotify-sync-tag retags the list
  # once sockseek is done, so a beets failure never touches a download.
  enqueue = pkgs.writeShellScript "spotify-sync-enqueue" ''
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" |
      ${lib.getExe' pkgs.util-linux "flock"} "$STATE_DIR/beets-queue.lock" \
        ${lib.getExe' pkgs.coreutils "tee"} -a "$STATE_DIR/beets-queue" >/dev/null
  '';

  # Metadata: every candidate from MusicBrainz and Deezer is scored against
  # the file, and the closest wins. Below the threshold the file keeps its
  # own tags (quiet_fallback: asis), so an unsure match never overwrites good
  # tags with wrong ones.
  #
  # Spotify is left out here. Every search candidate costs it two single-item
  # requests, and the backfill's few thousand got this app locked out of
  # them for 17 hours on 2026-11-15 (429, Retry-After 60517), the app
  # sockseek needs too. beets-spotify.yaml adds it back for songs sockseek
  # reported a Spotify track for: two requests each, and the only source
  # that also names a single song's album.
  beetsSettings = {
    directory = musicDir;
    library = "${stateDir}/beets/library.db";
    # versionguard: see beets-plugins/versionguard.py.
    pluginpath = [
      "${builtins.path {
        path = ./beets-plugins;
        name = "beets-plugins";
      }}"
    ];
    plugins = ["musicbrainz" "deezer" "versionguard" "fetchart" "embedart" "lyrics" "lastgenre"];
    ui.color = false;
    import = {
      # Tags only: files stay where sockseek put them, because its
      # indexes and the .m3u playlists point at those paths.
      write = true;
      copy = false;
      move = false;
      resume = false;
      incremental = false;
      quiet_fallback = "asis";
      duplicate_action = "keep";
      log = "${stateDir}/beets/import.log";
    };
    match = {
      # beets' default (0.04) only trusts near-perfect matches. A correct
      # album still scores around 0.1 when the uploader's folder lacks a
      # bonus track or the release country differs; 0.15 accepts those
      # and still rejects other albums, which scored 0.4 and up in tests.
      strong_rec_thresh = 0.15;
      # A file's leftover IDs from another release (often a compilation)
      # would otherwise outweigh title, artist and length, and sink even
      # the exact Spotify track a song was downloaded for.
      distance_weights.track_id = 0.0;
      preferred = {
        countries = ["DE" "XW"];
        media = ["Digital Media|File"];
      };
    };
    # beets adds 0.5 to any candidate not from MusicBrainz by default,
    # which made Spotify and Deezer lose even with identical data.
    musicbrainz.data_source_mismatch_penalty = 0.0;
    deezer.data_source_mismatch_penalty = 0.0;
    fetchart = {
      auto = true;
      minwidth = 500;
      maxwidth = 1500;
      # The uploader's own scan first, when it is big enough; then the
      # cover of the release beets matched: the Cover Art Archive for a
      # MusicBrainz match, the Deezer album's own cover (cover_art_url) for a
      # Deezer match. "spotify" reads the public album page, not the API.
      # No "itunes": without an exact hit it takes the first search result,
      # and on 2026-11-16 put Maroon 5's "Girls Like You" on Juju's "44 ME",
      # which iTunes does not carry.
      sources = ["filesystem" "coverart" "cover_art_url" "spotify"];
    };
    embedart.auto = true;
    # Synced lyrics from LRCLIB; Navidrome shows them line by line.
    lyrics = {
      auto = true;
      synced = true;
      sources = ["lrclib"];
    };
    lastgenre = {
      auto = true;
      count = 3;
      separator = "; ";
    };
  };

  # Both units run as spotify-sync with the same sandbox; only the network
  # differs.
  hardening = {
    User = "spotify-sync";
    Group = "media";
    # Downloads must stay writable by the media group, and readable by
    # Navidrome, which is not in it.
    UMask = "0002";
    StateDirectory = "spotify-sync";
    StateDirectoryMode = "0700";
    WorkingDirectory = stateDir;
    ProtectSystem = "strict";
    ReadWritePaths = [musicDir];
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    NoNewPrivileges = true;
    RestrictSUIDSGID = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    LockPersonality = true;
    RestrictNamespaces = true;
    RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
    SystemCallArchitectures = "native";
  };
in {
  config = lib.mkIf hasSecrets {
    # {{{ Secrets
    sops.secrets = lib.genAttrs secretNames (_: {sopsFile = ../../secrets.yaml;});
    sops.templates."sockseek.conf" = {
      owner = "spotify-sync";
      content = ''
        username = ${config.sops.placeholder.soulseek_username}
        password = ${config.sops.placeholder.soulseek_password}
        spotify-id = ${config.sops.placeholder.spotify_sync_client_id}
        spotify-secret = ${config.sops.placeholder.spotify_sync_client_secret}
        spotify-refresh = ${config.sops.placeholder.spotify_sync_refresh_token}

        pref-format = flac
        # Mullvad forwards no ports, so nobody could reach a listener anyway.
        no-listen = true
        # One folder per Spotify album, named from Spotify's metadata, so a
        # song's folder does not depend on how its uploader tagged it. Tag
        # folders split albums whose tracks carry different artist tags, and
        # sockseek then dropped the cover in their common parent, the library
        # root. Saved albums override this in spotify-sync.sh. Navidrome
        # groups albums by tag, so the layout only matters on disk.
        name-format = {sartist( - )salbum|albumartist( - )album|sartist}/${fileFormat}
        # Each source keeps its own index, so a song in two playlists would be
        # fetched twice; matching against the library by tag catches that and
        # still lists the existing file in the second .m3u.
        skip-music-dir = ${musicDir}
        skip-mode-music-dir = tag
        # What an album download that never completes leaves behind goes out
        # of the library: sockseek's default, {output dir}/failed, put a
        # second Kato and Ski Aggu album into Navidrome. A later run fetches
        # the album again.
        incomplete-album-action = move:${stateDir}/incomplete
        # Songs carry their Spotify URI, so beets can tag them from exactly
        # that track; files of an album download do not, and are tagged with
        # their album instead (scope=album, {path} is then the folder).
        on-complete = when=success scope=track lock -- ${enqueue} track "{uri}" "{path}"
        on-complete = + when=success scope=album lock -- ${enqueue} album - "{path}"
      '';
    };
    # Two configs over one library: Spotify only looks up songs whose exact
    # track sockseek reported; see beetsSettings.
    sops.templates."beets.yaml" = {
      owner = "spotify-sync";
      content = builtins.toJSON beetsSettings;
    };
    sops.templates."beets-spotify.yaml" = {
      owner = "spotify-sync";
      content = builtins.toJSON (beetsSettings
        // {
          plugins = beetsSettings.plugins ++ ["spotify"];
          spotify = {
            data_source_mismatch_penalty = 0.0;
            client_id = config.sops.placeholder.spotify_sync_client_id;
            client_secret = config.sops.placeholder.spotify_sync_client_secret;
          };
        });
    };
    # }}}
    # {{{ Service
    users.users.spotify-sync = {
      isSystemUser = true;
      group = "media";
      home = stateDir;
    };

    systemd.services.spotify-sync = {
      description = "Download the Spotify library over Soulseek";
      # In an album download each file's source artist is guessed from its
      # file name and can differ per track; {item-name} is the album job's
      # "Artist - Album" straight from Spotify. Set here rather than in
      # serviceConfig.Environment, which would not quote the spaces.
      environment.ALBUM_NAME_FORMAT = "{item-name}/${fileFormat}";
      # Through Mullvad, like the torrent client.
      vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };
      # Tagging runs after every sync, finished or failed.
      wants = ["spotify-sync-tag.service"];
      # A switch would otherwise kill a running sync, start it again and wait
      # the whole run out (47 minutes on 2026-11-15). The timer's next run
      # picks up the new unit anyway.
      restartIfChanged = false;
      serviceConfig =
        hardening
        // {
          Type = "oneshot";
          ExecStart = lib.getExe sync;
          Environment = [
            "HOME=${stateDir}"
            "MUSIC_DIR=${musicDir}"
            "STATE_DIR=${stateDir}"
            "SOCKSEEK_CONFIG=${config.sops.templates."sockseek.conf".path}"
          ];
          # The script asks the Spotify API itself which playlists exist.
          LoadCredential = [
            "client-id:${config.sops.secrets.spotify_sync_client_id.path}"
            "client-secret:${config.sops.secrets.spotify_sync_client_secret.path}"
            "refresh-token:${config.sops.secrets.spotify_sync_refresh_token.path}"
          ];
          TimeoutStartSec = "2h";
          # .NET JIT-compiles, so MemoryDenyWriteExecute stays off.
        };
    };

    # Outside the VPN on purpose: metadata lookups are not downloads, and
    # MusicBrainz rate-limits per address, which a shared Mullvad exit
    # exhausts. After= on a oneshot waits until the sync has finished.
    systemd.services.spotify-sync-tag = {
      description = "Tag new Spotify downloads with beets";
      # Quoted by NixOS, unlike serviceConfig.Environment: names have spaces.
      environment.MIXES_LEAVE_OUT = lib.concatStringsSep ";" leaveOutOfGenreMixes;
      after = ["spotify-sync.service"];
      restartIfChanged = false;
      serviceConfig =
        hardening
        // {
          Type = "oneshot";
          ExecStart = lib.getExe tag;
          Environment = [
            "HOME=${stateDir}"
            "MUSIC_DIR=${musicDir}"
            "STATE_DIR=${stateDir}"
            "BEETS_CONFIG=${config.sops.templates."beets.yaml".path}"
            "BEETS_SPOTIFY_CONFIG=${config.sops.templates."beets-spotify.yaml".path}"
            "BEETSDIR=${stateDir}/beets"
          ];
          # The first run backfills the whole library at MusicBrainz' one
          # request per second.
          TimeoutStartSec = "6h";
        };
    };

    systemd.timers.spotify-sync = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "10min";
        # Measured from the end of the last run, so a long first sync never
        # overlaps the next one.
        OnUnitInactiveSec = "15min";
        # The Release Radar is due then; see spotify-sync.sh.
        OnCalendar = "Fri *-*-* 01:00:00";
      };
    };

    systemd.tmpfiles.settings.spotifySync."${musicDir}/playlists".d = {
      mode = "2775";
      user = "spotify-sync";
      group = "media";
    };
    # }}}
    # {{{ Persistence
    # The per-playlist indexes record what was already fetched; losing them
    # only means a slower next run, since sockseek also skips existing files.
    yomi.persistence.at.state.apps.spotify-sync.directories = [
      {
        directory = stateDir;
        mode = "u=rwx,g=,o=";
        user = "spotify-sync";
        group = "media";
      }
    ];
    # }}}
  };
}
