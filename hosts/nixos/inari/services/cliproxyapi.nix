{
  config,
  lib,
  pkgs,
  upkgs,
  ...
}: let
  pilot = config.yomi.pilot.name;
  port = config.yomi.ports.cliproxyapi;
  # Take the newer Nixpkgs package without moving every unstable package on Inari.
  package = upkgs.cliproxyapi.overrideAttrs (finalAttrs: {
    version = "7.3.10";
    src = upkgs.fetchFromGitHub {
      owner = "router-for-me";
      repo = "CLIProxyAPI";
      tag = "v${finalAttrs.version}";
      hash = "sha256-pKguqvvQA1IVIE4f3qQbZ8VOWEcY4evkyacyYt36+T8=";
    };
    vendorHash = "sha256-r3yWkdMcM40G9jV7MxW/qNv3E9WrHavFilW24quEf+8=";
  });
  plugin = pkgs.cliproxyapi-copilot-plugin;
  managementKeyPath = config.sops.secrets.cliproxyapi_management_key.path;
  # Gates a loopback-only endpoint against stray local processes, same trust
  # level as t3code's own inlined per-session bearer tokens. Rotate by editing
  # this string and switching.
  #
  # It is deliberately not in sops, and the reasoning is worth writing down
  # because the repository is mirrored to a public forge. Both consumers need
  # the literal value at build time: this server's config, and opencode's
  # provider block below -- which is also how t3code reaches cliproxy, since
  # t3code has no provider of its own for it and only sees cliproxy/gpt-4.1
  # and friends as models under the opencode provider. Moving it to sops means
  # rendering opencode's config at runtime, and the value would still sit
  # world-readable in the nix store afterwards. The only thing that buys is
  # keeping it out of the mirror, which is not worth restructuring how the
  # agents are configured.
  #
  # If that trade stops being acceptable, the cheaper answer is to drop
  # api-keys entirely and let filesystem and loopback be the boundary, rather
  # than to hide a key that every local process can read anyway.
  apiKey = "ac44eaaf0d9eab6ff1eb768ec279911712f1291014cdabf68f69bb89fdc04f74";

  configTemplate = (pkgs.formats.yaml {}).generate "cliproxyapi-config.yaml" {
    host = "127.0.0.1";
    inherit port;
    auth-dir = "~/.cli-proxy-api";
    api-keys = [apiKey];
    remote-management = {
      allow-remote = false;
      secret-key = "__CLIPROXYAPI_MANAGEMENT_KEY__";
    };
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
  sops.secrets.cliproxyapi_management_key = {
    sopsFile = ../secrets.yaml;
    owner = pilot;
  };

  home-manager.users.${pilot} = {config, ...}: {
    yomi.persistence.at.state.apps.cliproxyapi.directories = [
      "${config.home.homeDirectory}/.cli-proxy-api"
    ];

    # Surfaced through t3code's existing OpenCode provider driver, which
    # queries this same opencode instance's connected-provider inventory.
    # Ceiling is the gpt-4.1/gpt-4o family: Copilot's backend rejects any
    # other explicit model on a Student/Free auto-only plan.
    programs.opencode.settings.provider.cliproxy = {
      npm = "@ai-sdk/openai-compatible";
      name = "GitHub Copilot (CLIProxyAPI)";
      options = {
        baseURL = "http://127.0.0.1:${toString port}/v1";
        inherit apiKey;
      };
      models = {
        "gpt-4.1" = {};
        "gpt-4o" = {};
        "gpt-4o-mini" = {};
      };
    };

    systemd.user.services.cliproxyapi = {
      Unit = {
        Description = "CLIProxyAPI (GitHub Copilot bridge for opencode)";
        After = ["network.target"];
      };
      Service = {
        RuntimeDirectory = "cliproxyapi";
        ExecStartPre = pkgs.writeShellScript "cliproxyapi-render-config" ''
          set -euo pipefail
          management_key="$(cat ${managementKeyPath})"
          sed \
            -e "s/__CLIPROXYAPI_MANAGEMENT_KEY__/$management_key/" \
            ${configTemplate} > "$RUNTIME_DIRECTORY/config.yaml"
          chmod 600 "$RUNTIME_DIRECTORY/config.yaml"
        '';
        ExecStart = "${lib.getExe package} -config %t/cliproxyapi/config.yaml";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
