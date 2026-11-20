{
  config,
  lib,
  pkgs,
  ...
}: let
  images = import ../../images.nix;
  stateDir = "/persist/state/var/lib/audiomuse";
  cacheDir = "/var/cache/audiomuse";
  port = config.yomi.ports.audiomuse;
  # Reachable only inside the containers' shared network namespace; see below.
  database = {
    POSTGRES_USER = "audiomuse";
    POSTGRES_PASSWORD = "audiomuse";
    POSTGRES_DB = "audiomusedb";
  };
  # The web app and the analysis workers are one image, told apart by
  # SERVICE_TYPE.
  app = role: {
    image = images.audiomuse;
    autoStart = true;
    dependsOn = ["audiomuse-postgres"];
    environment =
      database
      // {
        SERVICE_TYPE = role;
        POSTGRES_HOST = "127.0.0.1";
        POSTGRES_PORT = "5432";
        TEMP_DIR = "/app/temp_audio";
        TZ = config.time.timeZone;
      };
    volumes = [
      # Songs fetched from Navidrome for the analysis, and AudioMuse's own
      # plugins; both are fetched again when lost.
      "${cacheDir}/${role}/temp:/app/temp_audio"
      "${cacheDir}/${role}/plugins:/app/plugin/installed"
    ];
    log-driver = "journald";
    extraOptions = ["--network=container:audiomuse-postgres"];
  };
in {
  # AudioMuse-AI analyses every song in Navidrome by its sound (tempo,
  # energy, mood) and answers "more like this". Its Navidrome plugin feeds
  # that into Instant Mix and artist radio, which Symfonium uses with
  # "use similar tracks for radio mix". Nothing leaves inari: the songs are
  # read from Navidrome and the models run locally.
  #
  # Set up once in its web UI: media server Navidrome at
  # https://music.hugo-berendi.de with a Navidrome login, then the first
  # analysis. In Navidrome, enable the AudioMuse plugin and set its API URL
  # to http://127.0.0.1:8521 (yomi.ports.audiomuse).

  # {{{ Reverse proxy
  # Private access through Pangolin, like Navidrome.
  yomi.nginx.at.audiomuse.port = port;
  # }}}
  # {{{ Containers
  # One network namespace, like a pod: the database's container owns it,
  # and the app and the workers join it. PostgreSQL then listens on that
  # loopback alone, and no new Docker network is needed: a network of its
  # own would need its bridge in nftables, and any change there restarts
  # every container on inari. On Docker's default bridge the workers reach
  # Navidrome through nginx, as https://music.hugo-berendi.de.
  virtualisation.oci-containers.containers = {
    audiomuse-postgres = {
      image = images.audiomuse-postgres;
      autoStart = true;
      environment = database // {TZ = config.time.timeZone;};
      volumes = ["${stateDir}/postgres:/var/lib/postgresql/data"];
      cmd = ["postgres" "-c" "listen_addresses=127.0.0.1"];
      # The web app's port, published by the namespace's owner.
      ports = ["127.0.0.1:${toString port}:8000"];
      log-driver = "journald";
    };
    audiomuse-flask = app "flask";
    audiomuse-worker = app "worker";
  };
  # The app and workers live in the database container's namespace, which
  # is gone when it restarts; they have to follow it.
  systemd.services = lib.genAttrs ["docker-audiomuse-flask" "docker-audiomuse-worker"] (_: {
    bindsTo = ["docker-audiomuse-postgres.service"];
    partOf = ["docker-audiomuse-postgres.service"];
  });
  # }}}
  # {{{ Storage
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 root root - -"
    "d ${cacheDir} 0700 root root - -"
  ];
  # The analysis is rebuilt from the music when lost, and a live copy of
  # PostgreSQL's files is no backup anyway.
  yomi.restic.sets.state.exclude = [stateDir];
  # }}}
  # {{{ Navidrome
  services.navidrome = {
    plugins = [pkgs.audiomuse-navidrome-plugin];
    # Plugins answer only when named here. AudioMuse first, so Instant Mix
    # asks it before the online agents, which only know popular songs.
    settings.Agents = "audiomuseai,deezer,lastfm,listenbrainz";
  };
  # }}}
}
