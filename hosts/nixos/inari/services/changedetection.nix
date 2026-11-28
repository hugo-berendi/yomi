{
  config,
  lib,
  pkgs,
  ...
}: let
  dockerNetwork = import ../lib/docker-network.nix;
  dataDir = "/persist/state/var/lib/changedetection";
  networkName = "changedetection_default";
  port = config.yomi.ports.changedetection;
  notificationUrl = pkgs.writeShellApplication {
    name = "changedetection-notification-url";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      password=$(cat ${config.sops.secrets.no_reply_smtp_password.path})
      encoded=$(printf '%s' "$password" | ${lib.getExe pkgs.jq} -sRr @uri)
      echo "mailtos://no-reply%40tengu.hugo-berendi.de:$encoded@smtp.migadu.com?to=personal@hugo-berendi.de&from=no-reply%40tengu.hugo-berendi.de&name=Changedetection"
    '';
  };

  setupNotifications = pkgs.writeShellScript "changedetection-setup-notifications" ''
    set -euo pipefail
    export notification_url
    notification_url=$(${lib.getExe notificationUrl})
    api="http://127.0.0.1:${toString port}/api/v1/notifications"
    jq=${lib.getExe pkgs.jq}

    request() {
      printf 'X-Api-Key: %s\n' "$token" |
        ${lib.getExe pkgs.curl} --silent --show-error --fail --max-time 5 \
          --header @- "$@" "$api"
    }

    for ((attempt = 0; attempt < 30; attempt++)); do
      datastore="${dataDir}/changedetection.json"
      if [ ! -e "$datastore" ]; then
        datastore="${dataDir}/url-watches.json"
      fi
      if token=$("$jq" -er '.settings.application.api_access_token // ""' "$datastore" 2>/dev/null) \
        && current=$(request 2>/dev/null); then
        present=$(printf '%s' "$current" | "$jq" -r '.notification_urls | index(env.notification_url) != null')
        if [ "$present" = false ]; then
          request --request POST --header "Content-Type: application/json" \
            --data-binary @<("$jq" -nc '{notification_urls: [env.notification_url]}') >/dev/null
        fi
        exit 0
      fi
      sleep 2
    done
    echo "changedetection notification API unavailable or API key rejected" >&2
    exit 1
  '';
in {
  # {{{ Ports
  yomi.ports = {
    changedetection = 8492;
  };
  # }}}
  # {{{ Reverse proxy
  # Reachable without a login from the LAN.
  yomi.web.at.changedetection = {
    transport = "nginx";
    authentication = "none";
    homepage = {
      group = "Tooling";
      name = "Changedetection.io";
      icon = "changedetection.svg";
      description = "Website change monitoring";
    };
  };
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
      ${dockerNetwork {
        name = networkName;
        options = ["--opt com.docker.network.bridge.name=br-changedet"];
      }}
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
    image = (import ../images.nix).sockpuppetbrowser;
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
    image = (import ../images.nix).changedetection;
    autoStart = true;
    dependsOn = ["changedetection-browser"];
    ports = ["127.0.0.1:${toString port}:5000"];
    volumes = ["${dataDir}:/datastore"];
    environment = {
      PORT = "5000";
      BASE_URL = config.yomi.web.at.changedetection.url;
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

      # Keep activation bounded while the container initializes its datastore.
      TimeoutStartSec = "300";
    };
    wantedBy = ["multi-user.target"];
  };
  # }}}
}
