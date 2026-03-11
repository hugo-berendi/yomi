{
  config,
  pkgs,
  ...
}: let
  host = config.yomi.cloudflared.at.notes.host;
  url = config.yomi.cloudflared.at.notes.url;
  port = config.yomi.cloudflared.at.notes.port;
  networkName = "affine_default";
  appImage = "ghcr.io/toeverything/affine:stable";
  storageDir = "/persist/state/affine/storage";
  configDir = "/persist/state/affine/config";
  postgresDir = "/persist/state/affine/postgres";
  envFile = config.sops.templates."affine.env".path;
  affineConfigFile = config.sops.templates."affine-config.json".path;
  migrationScript = pkgs.writeShellScript "affine-migration" ''
    set -eu

    until ${pkgs.docker}/bin/docker exec affine-postgres pg_isready -U affine -d affine >/dev/null 2>&1; do
      sleep 2
    done

    until ${pkgs.docker}/bin/docker exec affine-valkey valkey-cli ping >/dev/null 2>&1; do
      sleep 2
    done

    exec ${pkgs.docker}/bin/docker run --rm \
      --network=${networkName} \
      --env-file "${envFile}" \
      -v "${storageDir}:/root/.affine/storage" \
      -v "${configDir}:/root/.affine/config" \
      -v "${affineConfigFile}:/root/.affine/config/config.json:ro" \
      "${appImage}" \
      sh -c 'node ./scripts/self-host-predeploy.js'
  '';
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.notes = {
    port = config.yomi.ports.affine;
    subdomain = "notes";
  };
  # }}}
  # {{{ Secrets
  sops.secrets.affine_db_password.sopsFile = ../secrets.yaml;
  sops.secrets.affine_oidc_client_id.sopsFile = ../secrets.yaml;
  sops.secrets.affine_oidc_client_secret.sopsFile = ../secrets.yaml;

  sops.templates."affine.env".content = ''
    DB_USERNAME=affine
    DB_PASSWORD=${config.sops.placeholder.affine_db_password}
    DB_DATABASE=affine
    POSTGRES_USER=affine
    POSTGRES_PASSWORD=${config.sops.placeholder.affine_db_password}
    POSTGRES_DB=affine
    AFFINE_SERVER_HTTPS=true
    AFFINE_SERVER_HOST=${host}
    AFFINE_SERVER_EXTERNAL_URL=${url}
    AFFINE_SERVER_PORT=3010
    DATABASE_URL=postgresql://affine:${config.sops.placeholder.affine_db_password}@postgres:5432/affine
    REDIS_SERVER_HOST=redis
    REDIS_SERVER_PORT=6379
    REDIS_SERVER_DATABASE=0
    AFFINE_INDEXER_ENABLED=false
  '';

  sops.templates."affine-config.json".content = builtins.toJSON {
    "$schema" = "https://github.com/toeverything/affine/releases/latest/download/config.schema.json";
    server.name = "Yomi Notes";
    auth = {
      allowSignup = true;
      allowSignupForOauth = true;
    };
    oauth."providers.oidc" = {
      issuer = config.yomi.cloudflared.at.pocket-id.url;
      clientId = config.sops.placeholder.affine_oidc_client_id;
      clientSecret = config.sops.placeholder.affine_oidc_client_secret;
      args = {
        scope = "openid profile email";
        claim_id = "preferred_username";
        claim_email = "email";
        claim_name = "name";
      };
    };
  };
  # }}}
  # {{{ Storage
  systemd.tmpfiles.rules = [
    "d ${storageDir} 0750 root root"
    "d ${configDir} 0750 root root"
    "d ${postgresDir} 0700 root root"
  ];
  # }}}
  # {{{ Network
  systemd.services."docker-network-affine_default" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f ${networkName}";
    };
    script = ''
      docker network inspect ${networkName} || docker network create ${networkName}
    '';
    wantedBy = ["multi-user.target"];
  };
  # }}}
  # {{{ Containers
  virtualisation.oci-containers.containers.affine-postgres = {
    image = "pgvector/pgvector:pg16";
    environmentFiles = [envFile];
    volumes = [
      "${postgresDir}:/var/lib/postgresql/data"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=postgres"
      "--network=${networkName}"
    ];
  };

  virtualisation.oci-containers.containers.affine-valkey = {
    image = "valkey/valkey:alpine";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=redis"
      "--network=${networkName}"
    ];
  };

  virtualisation.oci-containers.containers.affine = {
    image = appImage;
    dependsOn = [
      "affine-postgres"
      "affine-valkey"
    ];
    environmentFiles = [envFile];
    ports = ["127.0.0.1:${toString port}:3010"];
    volumes = [
      "${storageDir}:/root/.affine/storage"
      "${configDir}:/root/.affine/config"
      "${affineConfigFile}:/root/.affine/config/config.json:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=affine"
      "--network=${networkName}"
    ];
  };
  # }}}
  # {{{ Service ordering
  systemd.services.docker-affine-postgres = {
    after = ["docker-network-affine_default.service"];
    requires = ["docker-network-affine_default.service"];
  };

  systemd.services.docker-affine-valkey = {
    after = ["docker-network-affine_default.service"];
    requires = ["docker-network-affine_default.service"];
  };

  systemd.services.docker-affine = {
    path = [pkgs.docker];
    preStart = ''
      ${migrationScript}
    '';
    after = [
      "docker-network-affine_default.service"
      "docker-affine-postgres.service"
      "docker-affine-valkey.service"
    ];
    requires = [
      "docker-network-affine_default.service"
      "docker-affine-postgres.service"
      "docker-affine-valkey.service"
    ];
  };
  # }}}
}
