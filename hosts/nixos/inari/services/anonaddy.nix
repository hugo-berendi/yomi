{
  config,
  lib,
  pkgs,
  ...
}: let
  port = config.yomi.ports.anonaddy;
  dataDir = "/persist/data/media";
  configDir = "/persist/state/var/lib/qbittorrent";
  usenetConfigDir = "/persist/state/var/lib/sabnzbd";
in {
  # {{{ Networking & storage
  yomi.nginx.at.addy.port = port;
  sops.secrets.vpn_env.sopsFile = ../secrets.yaml;
  systemd.tmpfiles.rules = [
    "d ${dataDir} 777 ${config.users.users.pilot.name} users"
    "d ${configDir}"
  ];
  # }}}
  # {{{ AnonAddy
  # Containers
  virtualisation.oci-containers.containers."addy" = {
    image = "anonaddy/anonaddy:latest";
    environment = {
      "ANONADDY_DOMAIN" = "yurei.hugo-berendi.de";
      "ANONADDY_HOSTNAME" = config.yomi.nginx.at.addy.url;
      "ANONADDY_RETURN_PATH" = "bounce@hugo-berendi.de";
      "ANONADDY_DNS_RESOLVER" = "127.0.0.1";
      "APP_DEBUG" = "false";
      "APP_URL" = "http://127.0.0.1:8000";
      "DB_HOST" = "db";
      "REDIS_HOST" = "redis";
      "REAL_IP_FROM" = "0.0.0.0/32";
      "REAL_IP_HEADER" = "X-Forwarded-For";
      "TZ" = "Europe/Berlin";
      "PGID" = "1000";
      "PUID" = "1000";
      "ANONADDY_ADDITIONAL_USERNAME_LIMIT" = "3";
      "ANONADDY_ADMIN_USERNAME" = "addy";
      "ANONADDY_BANDWIDTH_LIMIT" = "104857600";
      "ANONADDY_ENABLE_REGISTRATION" = "true";
      "ANONADDY_LIMIT" = "200";
      "ANONADDY_NEW_ALIAS_LIMIT" = "10";
      "ANONADDY_SECRET" = "";
      "DB_DATABASE" = "";
      "DB_PASSWORD" = "";
      "DB_USERNAME" = "";
      "LOG_IP_VAR" = "remote_addr";
      "MAIL_FROM_ADDRESS" = "addy@example.com";
      "MAIL_FROM_NAME" = "addy.io";
      "MEMORY_LIMIT" = "256M";
      "OPCACHE_MEM_SIZE" = "128";
      "POSTFIX_DEBUG" = "false";
      "POSTFIX_SMTPD_TLS" = "false";
      "POSTFIX_SMTP_TLS" = "false";
      "UPLOAD_MAX_SIZE" = "16M";
    };
    volumes = [
      "/home/hugob/projects/docker-compose/addy/data:/data:rw"
    ];
    ports = [
      "25:25/tcp"
      "8000:8000/tcp"
    ];
    dependsOn = [
      "addy_db"
      "addy_redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=addy"
      "--network=addy_default"
    ];
  };
  systemd.services."docker-addy" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-addy_default.service"
    ];
    requires = [
      "docker-network-addy_default.service"
    ];
    partOf = [
      "docker-compose-addy-root.target"
    ];
    wantedBy = [
      "docker-compose-addy-root.target"
    ];
  };
  virtualisation.oci-containers.containers."addy_db" = {
    image = "mariadb:10";
    environment = {
      "MARIADB_RANDOM_ROOT_PASSWORD" = "yes";
    };
    volumes = [
      "/home/hugob/projects/docker-compose/addy/db:/var/lib/mysql:rw"
    ];
    cmd = ["mysqld" "--character-set-server=utf8mb4" "--collation-server=utf8mb4_unicode_ci"];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=db"
      "--network=addy_default"
    ];
  };
  systemd.services."docker-addy_db" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-addy_default.service"
    ];
    requires = [
      "docker-network-addy_default.service"
    ];
    partOf = [
      "docker-compose-addy-root.target"
    ];
    wantedBy = [
      "docker-compose-addy-root.target"
    ];
  };
  virtualisation.oci-containers.containers."addy_redis" = {
    image = "redis:4.0-alpine";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=redis"
      "--network=addy_default"
    ];
  };
  systemd.services."docker-addy_redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-addy_default.service"
    ];
    requires = [
      "docker-network-addy_default.service"
    ];
    partOf = [
      "docker-compose-addy-root.target"
    ];
    wantedBy = [
      "docker-compose-addy-root.target"
    ];
  };

  # Networks
  systemd.services."docker-network-addy_default" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f addy_default";
    };
    script = ''
      docker network inspect addy_default || docker network create addy_default
    '';
    partOf = ["docker-compose-addy-root.target"];
    wantedBy = ["docker-compose-addy-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-addy-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
  # }}}
}
