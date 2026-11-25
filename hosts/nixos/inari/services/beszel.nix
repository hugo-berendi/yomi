{
  config,
  lib,
  outputs,
  pkgs,
  ...
}: let
  port = config.yomi.ports.beszel;
  hub = config.services.beszel.hub;

  # {{{ Systems
  # Every host that runs the agent (profiles/services/beszel-agent.nix),
  # except the installer image, which runs it only while it is booted.
  # The hub syncs this list on every start: it creates a missing system and
  # deletes one that is not listed, history included. A system matches by
  # name, host and port, so changing any of them starts it from scratch.
  fleet = lib.filterAttrs (name: host: name != "iso" && (host.config.yomi.beszel-agent.enable or false)) outputs.nixosConfigurations;
  systems =
    lib.mapAttrsToList (name: _: {
      inherit name;
      # The hub reaches inari's own agent over SSH. The others cannot be
      # reached by name from here; their agents connect to the hub instead.
      host =
        if name == config.networking.hostName
        then "127.0.0.1"
        else name;
      # The agent's default listen port.
      port = 45876;
      # The hub tells agents apart by token. Each host appends its name to the
      # fleet's shared token, as its agent does.
      token = "${config.sops.placeholder.beszel_agent_token}-${name}";
      # Must name an existing Beszel user, or the hub refuses to start.
      users = [config.yomi.pilot.email];
    })
    fleet;
  # }}}
in {
  # {{{ Ports
  yomi.ports = {
    beszel = 8406;
  };
  # }}}
  # {{{ Service
  services.beszel.hub = {
    enable = true;
    host = "127.0.0.1";
    inherit port;
    dataDir = "/var/lib/beszel-hub";
    environment = {
      BESZEL_HUB_APP_URL = "https://monitoring.hugo-berendi.de";
      BESZEL_HUB_AUTO_LOGIN = config.yomi.pilot.email;
      DISABLE_PASSWORD_AUTH = "true";
      USER_CREATION = "true";
    };
  };

  # The hub reads beszel_data/config.yml when it starts. It holds the
  # tokens, so it comes from a sops template; the hub's dynamic user reads
  # it as a credential and copies it into place.
  sops.templates."beszel-hub-config.yml" = {
    # YAML parsers read JSON.
    content = builtins.toJSON {inherit systems;};
    restartUnits = ["beszel-hub.service"];
  };
  systemd.services.beszel-hub.serviceConfig = {
    LoadCredential = ["config.yml:${config.sops.templates."beszel-hub-config.yml".path}"];
    ExecStartPre = lib.mkBefore ["${pkgs.coreutils}/bin/install -D -m 0600 %d/config.yml ${hub.dataDir}/beszel_data/config.yml"];
  };
  # }}}
  # {{{ Networking
  # Pocket ID signs the browser in first (services/oauth2-proxy). Behind it,
  # BESZEL_HUB_AUTO_LOGIN signs every request in as the pilot, so the
  # sign-in is the only thing between the LAN and the hub's API.
  yomi.web.at.monitoring = {
    inherit port;
    transport = "nginx";
    authentication = "proxy";
    monitor = {
      enable = true;
      # The hub's own health check; it skips the sign-in below.
      path = "/api/health";
    };
  };
  # Paths that skip the sign-in. Agents bring their own token, which the hub
  # checks before it accepts the WebSocket, and the health check says only
  # that the API is up.
  services.nginx.virtualHosts.${config.yomi.web.at.monitoring.host}.locations = {
    "= /api/beszel/agent-connect" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = "auth_request off;";
    };
    "= /api/health" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      extraConfig = "auth_request off;";
    };
  };
  # }}}
}
