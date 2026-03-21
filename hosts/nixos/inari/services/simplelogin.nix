{
  config,
  pkgs,
  ...
}: let
  port = config.yomi.ports.simplelogin;
  networkName = "simplelogin_default";
  stateDir = "/persist/state/simplelogin";
  pgDataDir = "${stateDir}/db";
  slDataDir = "${stateDir}/sl";
  uploadDir = "${stateDir}/upload";
  dkimKeyPath = "${stateDir}/dkim.key";
  dkimPubKeyPath = "${stateDir}/dkim.pub.key";
  appImage = "simplelogin/app:latest";
  postfixImage = "simplelogin/postfix:latest";
in {
  # {{{ Reverse proxy
  yomi.nginx.at.alias.port = port;
  # }}}

  # {{{ Secrets
  sops.templates."simplelogin-db.env".content = ''
    POSTGRES_USER=simplelogin
    POSTGRES_DB=simplelogin
    POSTGRES_PASSWORD=${config.sops.placeholder.no_reply_smtp_password}
  '';

  sops.templates."simplelogin.env".content = ''
    URL=${config.yomi.nginx.at.alias.url}
    EMAIL_DOMAIN=yokai.hugo-berendi.de
    SUPPORT_EMAIL=no-reply@hugo-berendi.de
    EMAIL_SERVERS_WITH_PRIORITY=[(10, "mx.hugo-berendi.de.")]
    DISABLE_ALIAS_SUFFIX=1
    DKIM_PRIVATE_KEY_PATH=/dkim.key
    DB_URI=postgresql://simplelogin:${config.sops.placeholder.no_reply_smtp_password}@sl-db:5432/simplelogin
    FLASK_SECRET=${config.sops.placeholder.no_reply_smtp_password}
    GNUPGHOME=/sl/pgp
    LOCAL_FILE_UPLOAD=true
    POSTFIX_SERVER=simplelogin-postfix
    DISABLE_ONBOARDING=true
    DISABLE_REGISTRATION=1
    NAMESERVERS="1.1.1.1"
  '';

  sops.templates."simplelogin-postfix.env".content = ''
    ALIASES_DEFAULT_DOMAIN=yokai.hugo-berendi.de
    DB_HOST=sl-db
    DB_USER=simplelogin
    DB_PASSWORD=${config.sops.placeholder.no_reply_smtp_password}
    DB_NAME=simplelogin
    EMAIL_HANDLER_HOST=simplelogin-email
    POSTFIX_FQDN=mx.hugo-berendi.de
    RELAY_HOST=smtp.migadu.com
    RELAY_PORT=587
    RELAY_HOST_USERNAME=no-reply@hugo-berendi.de
    RELAY_HOST_PASSWORD=${config.sops.placeholder.no_reply_smtp_password}
    SIMPLELOGIN_COMPATIBILITY_MODE=v4
  '';
  # }}}

  # {{{ Storage
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 root root"
    "d ${pgDataDir} 0700 root root"
    "d ${slDataDir} 0750 root root"
    "d ${slDataDir}/pgp 0700 root root"
    "d ${uploadDir} 0750 root root"
  ];
  # }}}

  # {{{ Network
  systemd.services."docker-network-simplelogin_default" = {
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
  virtualisation.oci-containers.containers."simplelogin-db" = {
    image = "postgres:16-alpine";
    environmentFiles = [
      config.sops.templates."simplelogin-db.env".path
    ];
    volumes = [
      "${pgDataDir}:/var/lib/postgresql/data"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=sl-db"
      "--network=${networkName}"
    ];
  };

  virtualisation.oci-containers.containers."simplelogin-app" = {
    image = appImage;
    dependsOn = [
      "simplelogin-db"
    ];
    environmentFiles = [
      config.sops.templates."simplelogin.env".path
    ];
    ports = ["127.0.0.1:${toString port}:7777"];
    volumes = [
      "${slDataDir}:/sl"
      "${uploadDir}:/code/static/upload"
      "${dkimKeyPath}:/dkim.key:ro"
      "${dkimPubKeyPath}:/dkim.pub.key:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=simplelogin-app"
      "--network=${networkName}"
    ];
  };

  virtualisation.oci-containers.containers."simplelogin-email" = {
    image = appImage;
    dependsOn = [
      "simplelogin-db"
    ];
    cmd = ["python" "email_handler.py"];
    environmentFiles = [
      config.sops.templates."simplelogin.env".path
    ];
    ports = ["127.0.0.1:20381:20381"];
    volumes = [
      "${slDataDir}:/sl"
      "${uploadDir}:/code/static/upload"
      "${dkimKeyPath}:/dkim.key:ro"
      "${dkimPubKeyPath}:/dkim.pub.key:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=simplelogin-email"
      "--network=${networkName}"
    ];
  };

  virtualisation.oci-containers.containers."simplelogin-job-runner" = {
    image = appImage;
    dependsOn = [
      "simplelogin-db"
    ];
    cmd = ["python" "job_runner.py"];
    environmentFiles = [
      config.sops.templates."simplelogin.env".path
    ];
    volumes = [
      "${slDataDir}:/sl"
      "${uploadDir}:/code/static/upload"
      "${dkimKeyPath}:/dkim.key:ro"
      "${dkimPubKeyPath}:/dkim.pub.key:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=simplelogin-job-runner"
      "--network=${networkName}"
    ];
  };

  virtualisation.oci-containers.containers."simplelogin-postfix" = {
    image = postfixImage;
    dependsOn = [
      "simplelogin-db"
      "simplelogin-email"
    ];
    environmentFiles = [
      config.sops.templates."simplelogin-postfix.env".path
    ];
    ports = [
      "25:25/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=simplelogin-postfix"
      "--network=${networkName}"
    ];
  };
  # }}}

  # {{{ Init and ordering
  systemd.services.simplelogin-generate-dkim = {
    description = "Generate DKIM keypair for SimpleLogin";
    path = [pkgs.openssl];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      if [ ! -f ${dkimKeyPath} ] || [ ! -f ${dkimPubKeyPath} ]; then
        rm -f ${dkimKeyPath} ${dkimPubKeyPath}
        openssl genrsa -out ${dkimKeyPath} -traditional 1024
        openssl rsa -in ${dkimKeyPath} -pubout -out ${dkimPubKeyPath}
        chmod 0400 ${dkimKeyPath}
        chmod 0444 ${dkimPubKeyPath}
      fi
    '';
    after = [
      "docker-network-simplelogin_default.service"
    ];
    requires = [
      "docker-network-simplelogin_default.service"
    ];
    wantedBy = ["multi-user.target"];
  };

  systemd.services.simplelogin-init = {
    description = "Initialize and migrate SimpleLogin database";
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      until docker exec simplelogin-db pg_isready -U simplelogin -d simplelogin >/dev/null 2>&1; do
        sleep 2
      done

      docker run --rm \
        --network=${networkName} \
        --env-file ${config.sops.templates."simplelogin.env".path} \
        -v ${slDataDir}:/sl \
        -v ${uploadDir}:/code/static/upload \
        -v ${dkimKeyPath}:/dkim.key:ro \
        -v ${dkimPubKeyPath}:/dkim.pub.key:ro \
        ${appImage} flask db upgrade

      if [ ! -f ${stateDir}/.initialized ]; then
        docker run --rm \
          --network=${networkName} \
          --env-file ${config.sops.templates."simplelogin.env".path} \
          -v ${slDataDir}:/sl \
          -v ${uploadDir}:/code/static/upload \
          -v ${dkimKeyPath}:/dkim.key:ro \
          -v ${dkimPubKeyPath}:/dkim.pub.key:ro \
          ${appImage} python init_app.py
        touch ${stateDir}/.initialized
      fi
    '';
    after = [
      "docker-network-simplelogin_default.service"
      "simplelogin-generate-dkim.service"
      "docker-simplelogin-db.service"
    ];
    requires = [
      "docker-network-simplelogin_default.service"
      "simplelogin-generate-dkim.service"
      "docker-simplelogin-db.service"
    ];
    before = [
      "docker-simplelogin-app.service"
      "docker-simplelogin-email.service"
      "docker-simplelogin-job-runner.service"
      "docker-simplelogin-postfix.service"
    ];
    wantedBy = ["multi-user.target"];
  };

  systemd.services.docker-simplelogin-db = {
    after = ["docker-network-simplelogin_default.service"];
    requires = ["docker-network-simplelogin_default.service"];
  };

  systemd.services.docker-simplelogin-app = {
    after = [
      "docker-network-simplelogin_default.service"
      "simplelogin-init.service"
    ];
    requires = [
      "docker-network-simplelogin_default.service"
      "simplelogin-init.service"
    ];
  };

  systemd.services.docker-simplelogin-email = {
    after = [
      "docker-network-simplelogin_default.service"
      "simplelogin-init.service"
    ];
    requires = [
      "docker-network-simplelogin_default.service"
      "simplelogin-init.service"
    ];
  };

  systemd.services.docker-simplelogin-job-runner = {
    after = [
      "docker-network-simplelogin_default.service"
      "simplelogin-init.service"
    ];
    requires = [
      "docker-network-simplelogin_default.service"
      "simplelogin-init.service"
    ];
  };

  systemd.services.docker-simplelogin-postfix = {
    after = [
      "docker-network-simplelogin_default.service"
      "simplelogin-init.service"
      "docker-simplelogin-email.service"
    ];
    requires = [
      "docker-network-simplelogin_default.service"
      "simplelogin-init.service"
      "docker-simplelogin-email.service"
    ];
  };
  # }}}
}
