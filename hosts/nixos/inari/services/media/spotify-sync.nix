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
  sync = pkgs.writeShellApplication {
    name = "spotify-sync";
    runtimeInputs = [pkgs.sockseek pkgs.curl pkgs.jq pkgs.coreutils pkgs.findutils];
    text = builtins.readFile ./spotify-sync.sh;
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
      '';
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
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe sync;
        User = "spotify-sync";
        Group = "media";
        # Downloads must stay writable by the media group, and readable by
        # Navidrome, which is not in it.
        UMask = "0002";
        StateDirectory = "spotify-sync";
        StateDirectoryMode = "0700";
        WorkingDirectory = stateDir;
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
        # .NET JIT-compiles, so MemoryDenyWriteExecute stays off.
      };
    };

    systemd.timers.spotify-sync = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "10min";
        # Measured from the end of the last run, so a long first sync never
        # overlaps the next one.
        OnUnitInactiveSec = "15min";
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
