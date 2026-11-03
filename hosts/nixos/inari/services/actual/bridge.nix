{
  config,
  lib,
  pkgs,
  upkgs,
  ...
}: let
  server = config.services.actual.package;
  # The API bundle must match the server it talks to: it carries its own copy
  # of the budget schema and migrations, and an older client would refuse or,
  # worse, downgrade a newer budget. Bump this together with actual-server.
  apiVersion = "26.10.0";
  api = pkgs.runCommand "actual-app-api-${apiVersion}" {} ''
    mkdir -p $out
    tar -xzf ${pkgs.fetchurl {
      url = "https://registry.npmjs.org/@actual-app/api/-/api-${apiVersion}.tgz";
      hash = "sha256-ruSWWj5Rb8r9nx3fombiViRKOSIoIY9IdLXwNbqn8og=";
    }} -C $out --strip-components=1
  '';
  # The bundle's only runtime dependency is better-sqlite3, a native module.
  # actual-server already ships one built for its Node, so the bridge runs on
  # that same Node and borrows the server's node_modules.
  nodejs = upkgs.nodejs_24;
  hasBudgetPassword = builtins.match ".*[[:space:]]*actual_budget_password:.*" (builtins.readFile ../../secrets.yaml) != null;
  credentials =
    {
      session-token = config.sops.secrets.actual_bridge_session_token.path;
      api-key = config.sops.secrets.actual_bridge_api_key.path;
    }
    // lib.optionalAttrs hasBudgetPassword {
      budget-password = config.sops.secrets.actual_budget_password.path;
    };
in {
  warnings = lib.optional (server.version != apiVersion) ''
    actual-bridge pins @actual-app/api ${apiVersion} but actual-server is ${server.version}.
    Update apiVersion and its hash in hosts/nixos/inari/services/actual/bridge.nix.
  '';

  # {{{ Secrets
  # The session token is a row in Actual's own sessions table, owned by the
  # budget owner and never expiring; deleting that row revokes the bridge
  # without touching anyone's login. The API key guards the bridge itself,
  # since every local user can reach a loopback port.
  sops.secrets =
    {
      actual_bridge_session_token.sopsFile = ../../secrets.yaml;
      actual_bridge_api_key.sopsFile = ../../secrets.yaml;
    }
    // lib.optionalAttrs hasBudgetPassword {
      actual_budget_password.sopsFile = ../../secrets.yaml;
    };
  # }}}
  # {{{ n8n
  # Daily bank sync and categorisation; the JSON sits with the other
  # workflows, see docs/n8n.md.
  yomi.n8n.workflows.actual-budget.source = ../n8n/workflows/actual-budget.json;
  services.n8n.environment = {
    ACTUAL_BRIDGE_URL = "http://127.0.0.1:${toString config.yomi.ports.actual-bridge}";
    ACTUAL_URL = config.yomi.nginx.at.budget.url;
  };
  sops.templates."n8n-services.env".content = lib.mkAfter ''
    ACTUAL_BRIDGE_API_KEY=${config.sops.placeholder.actual_bridge_api_key}
  '';
  # }}}
  # {{{ Service
  systemd.services.actual-bridge = {
    description = "Loopback HTTP bridge from n8n to Actual Budget";
    after = ["actual.service" "network.target"];
    wants = ["actual.service"];
    wantedBy = ["multi-user.target"];
    environment = {
      ACTUAL_API_MODULE = "${api}/dist/index.js";
      NODE_PATH = "${server}/lib/actual/node_modules";
      NODE_ENV = "production";
      # Straight to the server on loopback: no TLS, DNS or nginx in the way.
      ACTUAL_SERVER_URL = "http://127.0.0.1:${toString config.yomi.ports.actual}";
      BRIDGE_PORT = toString config.yomi.ports.actual-bridge;
    };
    serviceConfig = {
      ExecStart = "${lib.getExe nodejs} ${./bridge.cjs}";
      DynamicUser = true;
      # The downloaded budget lives only on tmpfs and goes with the service.
      RuntimeDirectory = "actual-bridge";
      RuntimeDirectoryMode = "0700";
      WorkingDirectory = "/run/actual-bridge";
      LoadCredential = lib.mapAttrsToList (name: file: "${name}:${file}") credentials;
      Restart = "on-failure";
      RestartSec = "10s";

      # Same sandbox as the upstream actual unit, plus loopback-only network.
      CapabilityBoundingSet = "";
      LockPersonality = true;
      # MemoryDenyWriteExecute stays off: V8 needs writable executable pages.
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProcSubset = "pid";
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = ["@system-service" "@pkey"];
      IPAddressAllow = ["localhost"];
      IPAddressDeny = "any";
      UMask = "0077";
    };
  };
  # }}}
}
