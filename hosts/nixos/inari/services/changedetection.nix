{
  config,
  lib,
  pkgs,
  ...
}: let
  dataDir = "/persist/state/var/lib/changedetection";
  networkName = "changedetection_default";
  port = config.yomi.ports.changedetection;
  notificationUrl = pkgs.writeShellScript "changedetection-notification-url" ''
    set -euo pipefail
    password=$(cat ${config.sops.secrets.no_reply_smtp_password.path})
    encoded=$(printf '%s' "$password" | ${lib.getExe pkgs.jq} -sRr @uri)
    echo "mailtos://no-reply%40tengu.hugo-berendi.de:$encoded@smtp.migadu.com?to=personal@hugo-berendi.de&from=no-reply%40tengu.hugo-berendi.de&name=Changedetection"
  '';

  setupNotifications = pkgs.writeShellScript "changedetection-setup-notifications" ''
    set -euo pipefail
    url=$(${notificationUrl})
    api="http://127.0.0.1:${toString port}/api/v1/notifications"
    curl="${lib.getExe pkgs.curl} -sf --max-time 15 --retry 3 --retry-delay 2"

    for i in $(seq 1 90); do
      if $curl "http://127.0.0.1:${toString port}/" >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    sleep 3

    for i in $(seq 1 30); do
      if current=$($curl "$api" | ${lib.getExe pkgs.jq} -r --arg url "$url" '.notification_urls // [] | index($url)'); then
        if [ "$current" = "null" ]; then
          new_urls=$($curl "$api" | ${lib.getExe pkgs.jq} --arg url "$url" '{notification_urls: ((.notification_urls // []) + [$url])}')
          $curl -X POST \
            -H "Content-Type: application/json" \
            -d "$new_urls" \
            "$api"
        fi
        break
      fi
      sleep 2
    done
  '';
in {
  # {{{ Reverse proxy
  yomi.nginx.at.changedetection.port = port;
  # }}}
  # {{{ Secrets
  sops.secrets.no_reply_smtp_password = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ Network
  systemd.services."docker-network-changedetection_default" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f ${networkName}";
    };
    script = ''
      # A fixed bridge name so nftables can name it; an unnamed br-<hash> is not
      # in the input chain, so replies from the container were dropped and the
      # published port on 127.0.0.1 simply hung.
      docker network inspect ${networkName} || docker network create --opt com.docker.network.bridge.name=br-changedet ${networkName}
    '';
    wantedBy = ["multi-user.target"];
  };
  # }}}
  # {{{ Storage
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 0 0 - -"
  ];
  # }}}
  # {{{ Containers
  virtualisation.oci-containers.containers.changedetection-browser = {
    image = "dgtlmoon/sockpuppetbrowser:latest@sha256:1d8f72d2ce2085faed4232e5ae1e65c02efe5b831a18e127829b267c260b4fb2";
    autoStart = true;
    environment = {
      SCREEN_WIDTH = "1920";
      SCREEN_HEIGHT = "1024";
      SCREEN_DEPTH = "16";
      MAX_CONCURRENT_CHROME_PROCESSES = "10";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=browser"
      "--network=${networkName}"
    ];
  };

  virtualisation.oci-containers.containers.changedetection = {
    image = "ghcr.io/dgtlmoon/changedetection.io:latest@sha256:096dae27b5d677b89f0e810fff95a70403271aa3ff3b6437952d2db9be7e74c5";
    autoStart = true;
    dependsOn = ["changedetection-browser"];
    ports = ["127.0.0.1:${toString port}:5000"];
    volumes = ["${dataDir}:/datastore"];
    environment = {
      PORT = "5000";
      BASE_URL = config.yomi.nginx.at.changedetection.url;
      PLAYWRIGHT_DRIVER_URL = "ws://browser:3000";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=changedetection"
      "--network=${networkName}"
    ];
  };
  # }}}
  # {{{ Service ordering
  systemd.services.docker-changedetection-browser = {
    path = [pkgs.docker];
    preStart = ''
      docker network inspect ${networkName} >/dev/null 2>&1 || docker network create ${networkName}
    '';
    after = ["docker-network-changedetection_default.service"];
    requires = ["docker-network-changedetection_default.service"];
  };

  systemd.services.docker-changedetection = {
    path = [pkgs.docker];
    after = [
      "docker-network-changedetection_default.service"
      "docker-changedetection-browser.service"
    ];
    requires = [
      "docker-network-changedetection_default.service"
      "docker-changedetection-browser.service"
    ];
  };
  # }}}
  # {{{ Notification setup
  systemd.services.changedetection-setup-notifications = {
    description = "Configure changedetection.io global email notification";
    after = ["docker-changedetection.service"];
    requires = ["docker-changedetection.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = setupNotifications;

      # The retry loops look bounded, but each curl carries --max-time 15
      # --retry 3, so a single failing call takes over a minute and the whole
      # script can run for an hour and a half. Because this unit is part of
      # multi-user.target, that blocked every nixos-rebuild switch on the host
      # until it was killed by hand.
      TimeoutStartSec = "300";
    };
    wantedBy = ["multi-user.target"];
  };
  # }}}
}
