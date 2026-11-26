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
  # The sync wires itself up only once all of them are in secrets.yaml; see
  # ../../../lib/has-secret.nix.
  missingSecrets = lib.filter (name: !import ../../../lib/has-secret.nix name) secretNames;
  hasSecrets = missingSecrets == [];

  # File name inside an album folder: track number when tagged, else the
  # Soulseek file name as the last resort.
  fileFormat = "{track(. )artist( - )title|artist( - )title|sartist( - )stitle|slsk-filename}";

  # What gets synced follows the Spotify library itself (liked songs, saved
  # albums, own playlists), so adding music never means editing this file.
  # New releases of the library's artists, from Deezer.
  radar = pkgs.writers.writePython3Bin "spotify-sync-radar" {
    flakeIgnore = ["E501"];
  } (builtins.readFile ./radar.py);

  sync = pkgs.writeShellApplication {
    name = "spotify-sync";
    runtimeInputs = [pkgs.sockseek radar pkgs.curl pkgs.jq pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.util-linux];
    text = builtins.readFile ./sync.sh;
  };

  # Puts library songs into the playlists where sockseek wrote #FAIL.
  resolve = pkgs.writers.writePython3Bin "spotify-sync-resolve" {
    flakeIgnore = ["E501"];
  } (builtins.readFile ./resolve.py);

  # Lists the album folders that ended up without a cover.
  covers = pkgs.writers.writePython3Bin "spotify-sync-covers" {
    libraries = [pkgs.python3Packages.mutagen];
    flakeIgnore = ["E501"];
  } (builtins.readFile ./covers.py);

  # Writes the mixes per artist and genre, and a few lists.
  mixes = pkgs.writers.writePython3Bin "spotify-sync-mixes" {
    flakeIgnore = ["E501"];
  } (builtins.readFile ./mixes.py);
  # Draws their covers, and the Release Radar's.
  art = pkgs.writers.writePython3Bin "spotify-sync-art" {
    libraries = [pkgs.python3Packages.pillow pkgs.python3Packages.mutagen];
    flakeIgnore = ["E501"];
  } (builtins.replaceStrings ["@fonts@"] ["${pkgs.figtree}/share/fonts/opentype"] (builtins.readFile ./art.py));
  # Artists the genre mixes leave out. Kato's 80-song Zelda lullaby album
  # is tagged House and would be half of "Electronic"; it has its own mix.
  leaveOutOfGenreMixes = ["Kato"];

  # Songs beets tagged wrong, by the Deezer track each one is, retagged once
  # by spotify-sync-tag.sh (a path, below the music folder, is retagged again
  # when its ID changes). Found on 2026-11-17 and 18: singles from
  # compilation rips ("Bravo Hits", "Future Dance"), which kept the
  # compilation's tags and cover, two songs without an album, and a
  # YouTube rip titled "Juju - FDI (OFFICIAL VIDEO)".
  retag = {
    "Jaschu/Bravo Hits 130/Jaschu - Schnee von morgen.flac" = 3137060671;
    "Various Artists/Bravo Hits 123/Baby B3ns - Schmetterling.flac" = 2395976995;
    "Various Artists/Bravo Hits 130/Zsá Zsá & Replay Okay - bad bunnies.mp3" = 3339356611;
    "Various Artists/BRAVO Hits  2023/Ellice - ANGST>LIEBE.mp3" = 2480904621;
    "bac - Rosaroter Tee/17. bac - Rosaroter Tee.flac" = 3040569121;
    "21 Savage - american dream/21 Savage - redrum.flac" = 2614584352;
    "Carli/PINOCCHIO/Carli - Pinocchio.mp3" = 3792205442;
    "Various Artists/Future Dance Part 2/Baby B3ns; Yung Hurn - Liebe in Stereo.mp3" = 2816357052;
    "jujuvierundvierzig/Fick Dein Insta/Juju - Fick Dein Insta.wav" = 1809867107;
  };
  retagList = pkgs.writeText "spotify-sync-retag" (lib.concatStrings (lib.mapAttrsToList (path: id: "${toString id}\t${path}\n") retag));

  tag = pkgs.writeShellApplication {
    name = "spotify-sync-tag";
    runtimeInputs = [pkgs.beets resolve covers mixes art pkgs.curl pkgs.jq pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.util-linux];
    text = builtins.readFile ./tag.sh;
  };

  # sockseek runs this after every finished download. It only notes the file
  # (and, for Spotify songs, the track URI); spotify-sync-tag retags the list
  # once sockseek is done, so a beets failure never touches a download.
  enqueue = pkgs.writeShellScript "spotify-sync-enqueue" ''
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" |
      ${lib.getExe' pkgs.util-linux "flock"} "$STATE_DIR/beets-queue.lock" \
        ${lib.getExe' pkgs.coreutils "tee"} -a "$STATE_DIR/beets-queue" >/dev/null
  '';

  beetsSettings = import ./beets.nix {inherit musicDir stateDir;};

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
  config = lib.mkMerge [
    {
      warnings = lib.optional (!hasSecrets) "Spotify sync is off: ${lib.concatStringsSep ", " missingSecrets} not in inari's secrets.yaml.";
    }
    (lib.mkIf hasSecrets {
      # {{{ Secrets
      sops.secrets = lib.genAttrs secretNames (_: {sopsFile = ../../../secrets.yaml;});
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
        environment.RETAG_LIST = retagList;
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
    })
  ];
}
