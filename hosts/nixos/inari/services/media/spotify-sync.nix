{
  config,
  lib,
  pkgs,
  ...
}: let
  musicDir = "${config.nixarr.mediaDir}/library/music";
  stateDir = "/var/lib/spotify-sync";

  # name -> Spotify playlist URL. Only playlists the Spotify account owns or
  # collaborates on work: since February 2026 the API returns no tracks for
  # anyone else's, public or not. The name becomes the .m3u file Navidrome
  # imports as a playlist.
  playlists = {};

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
  enable = hasSecrets && playlists != {};

  sync = pkgs.writeShellApplication {
    name = "spotify-sync";
    runtimeInputs = [pkgs.sockseek];
    text = lib.concatStrings (lib.mapAttrsToList (name: url: ''
        echo "syncing ${name}"
        sockseek ${lib.escapeShellArg url} \
          --config ${config.sops.templates."sockseek.conf".path} \
          --output-dir ${musicDir} \
          --index-path ${stateDir}/${name}.index \
          --write-playlist \
          --playlist-path ${lib.escapeShellArg "${musicDir}/playlists/${name}.m3u"}
      '')
      playlists);
  };
in {
  config = lib.mkIf enable {
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
        # Tags when the file has them, Spotify's metadata when it does not.
        name-format = {albumartist|artist|sartist}/{album|salbum}/{artist( - )title|sartist( - )stitle}
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
      description = "Download new tracks from Spotify playlists over Soulseek";
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
        Environment = ["HOME=${stateDir}"];
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
