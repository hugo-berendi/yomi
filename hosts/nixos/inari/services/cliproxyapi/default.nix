{
  config,
  lib,
  pkgs,
  ...
}: let
  pilot = config.yomi.pilot.name;
  port = config.yomi.ports.cliproxyapi;
  # Address, port and key path the client wrappers use.
  proxy = import ../../../../../home/features/cli/ai/subscription-proxy.nix;
  # The pinned Go compiler is too old for this release. Use upstream's
  # plugin-enabled Linux build until nixpkgs supplies a recent enough Go.
  package = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "cliproxyapi";
    version = "8.0.44";
    src = pkgs.fetchurl {
      url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${finalAttrs.version}/CLIProxyAPI_${finalAttrs.version}_linux_amd64.tar.gz";
      sha256 = "3957c34fe4a95a37f5997ab63d78dca431fa1521997d7c2ab3bdfe169ad89307";
    };
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    dontUnpack = true;
    installPhase = ''
      mkdir -p "$out/bin"
      tar -xzf "$src" -C "$out/bin" cli-proxy-api
      mv "$out/bin/cli-proxy-api" "$out/bin/cliproxyapi"
    '';
    meta.mainProgram = "cliproxyapi";
  });
  plugin = pkgs.cliproxyapi-copilot-plugin;
  managementKeyPath = config.sops.secrets.cliproxyapi_management_key.path;
  apiKeyPath = config.sops.secrets.cliproxyapi_api_key.path;

  # v8 layout (config.example.yaml of the pinned release).
  configTemplate = (pkgs.formats.yaml {}).generate "cliproxyapi-config.yaml" {
    config-version = 8;
    server = {
      # All interfaces: loopback for opencode and the management poller, br0
      # and NetBird for the other machines. nftables admits br0 only through
      # the grant below and wt0 because it gets the LAN's ports; nothing else.
      host = "";
      inherit port;
    };
    access.api-keys = ["__CLIPROXYAPI_API_KEY__"];
    management = {
      allow-remote = false;
      secret-key = "__CLIPROXYAPI_MANAGEMENT_KEY__";
    };
    oauth.auth-dir = "~/.cli-proxy-api";
    # The scheduler always picks from the highest "priority" (a field in each
    # auth file) that has a ready credential, and only falls to a lower one
    # while the higher are cooling down after a quota error
    # (sdk/cliproxy/auth/scheduler.go, pickReadyLocked). The extra accounts
    # carry priority 10, the main ones none (0), so the extras are spent
    # first. fill-first keeps that order within a tier as well.
    routing.strategy = "fill-first";
    plugins = {
      enabled = true;
      dir = "${plugin}";
      configs.cliproxyapi-copilot = {
        enabled = true;
        priority = 100;
        github_client_id = "Iv1.b507a08c87ecfe98";
        github_scope = "read:user";
        github_base_url = "https://github.com";
        github_api_url = "https://api.github.com";
        copilot_api_url = "https://api.githubcopilot.com";
        oauth_timeout_seconds = 900;
        model_cache_ttl_seconds = 600;
        token_expiry_buffer_seconds = 300;
        # Only OpenAI's gpt-4.1/gpt-4o family is selectable on a Copilot
        # Student/Free plan; everything else 400s server-side as
        # model_not_supported, so there is nothing else to exclude here.
        excluded_model_prefixes = [];
      };
    };
  };
in {
  # {{{ Ports
  yomi.ports = {
    cliproxyapi = proxy.port;
  };
  # The proxy spends paid subscriptions, so the key is what keeps the rest of
  # the LAN out; it lives in sops and is never in the store.
  yomi.network.exposure.cliproxyapi.interface = "br0";
  # }}}
  sops.secrets = {
    cliproxyapi_management_key = {
      sopsFile = ../../secrets.yaml;
      owner = pilot;
    };
    cliproxyapi_api_key = {
      sopsFile = ./secrets.yaml;
      owner = pilot;
    };
  };

  home-manager.users.${pilot} = {config, ...}: {
    yomi.persistence.at.state.apps.cliproxyapi.directories = [
      "${config.home.homeDirectory}/.cli-proxy-api"
    ];

    # Where the Claude Code and Codex wrappers look; other machines get a copy
    # of the key at the same path by hand.
    home.file.${proxy.keyFile}.source = config.lib.file.mkOutOfStoreSymlink apiKeyPath;

    # Surfaced through t3code's existing OpenCode provider driver, which
    # queries this same opencode instance's connected-provider inventory.
    # Ceiling is the gpt-4.1/gpt-4o family: Copilot's backend rejects any
    # other explicit model on a Student/Free auto-only plan.
    programs.opencode.settings.provider.cliproxy = {
      npm = "@ai-sdk/openai-compatible";
      name = "GitHub Copilot (CLIProxyAPI)";
      options = {
        baseURL = "http://127.0.0.1:${toString port}/v1";
        # opencode reads the file when it loads its config.
        apiKey = "{file:~/${proxy.keyFile}}";
      };
      models = {
        "gpt-4.1" = {};
        "gpt-4o" = {};
        "gpt-4o-mini" = {};
      };
    };

    systemd.user.services.cliproxyapi = {
      Unit = {
        Description = "CLIProxyAPI (subscription and Copilot bridge for the coding agents)";
        After = ["network.target"];
      };
      Service = {
        RuntimeDirectory = "cliproxyapi";
        ExecStartPre = lib.getExe (pkgs.writeShellApplication {
          name = "cliproxyapi-render-config";
          runtimeInputs = [pkgs.coreutils pkgs.gnused];
          text = ''
            management_key="$(cat ${managementKeyPath})"
            api_key="$(cat ${apiKeyPath})"
            sed \
              -e "s/__CLIPROXYAPI_MANAGEMENT_KEY__/$management_key/" \
              -e "s/__CLIPROXYAPI_API_KEY__/$api_key/" \
              ${configTemplate} > "$RUNTIME_DIRECTORY/config.yaml"
            chmod 600 "$RUNTIME_DIRECTORY/config.yaml"
          '';
        });
        ExecStart = "${lib.getExe package} -config %t/cliproxyapi/config.yaml";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
