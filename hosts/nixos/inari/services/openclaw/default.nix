{
  config,
  inputs,
  pkgs,
  ...
}: let
  pilot = config.yomi.pilot.name;
in {
  nixpkgs.overlays = [inputs.nix-openclaw.overlays.default];

  home-manager.users.${pilot} = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [inputs.nix-openclaw.homeManagerModules.openclaw];

    nixpkgs.overlays = [inputs.nix-openclaw.overlays.default];

    sops.secrets.openclaw_telegram_bot_token = {
      sopsFile = ../../secrets.yaml;
    };

    sops.secrets.openclaw_gateway_auth_token = {
      sopsFile = ../../secrets.yaml;
    };

    sops.templates."openclaw.env".content = ''
      OPENCLAW_GATEWAY_TOKEN=${config.sops.placeholder.openclaw_gateway_auth_token}
      GH_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
      EXA_API_KEY=${config.sops.placeholder.EXA_API_KEY}
      SEARXNG_URL=${config.sops.placeholder.SEARXNG_URL}
      SEARXNG_BASE_URL=${config.sops.placeholder.SEARXNG_URL}
      OPENCODE_BIN=opencode
    '';

    programs.openclaw = {
      enable = true;
      toolNames = [
        "nodejs_22"
        "pnpm_10"
        "uv"
        "git"
        "gh"
        "lazygit"
        "just"
        "nix"
        "ripgrep"
        "fd"
        "ast-grep"
        "jq"
        "yq-go"
        "delta"
        "curl"
        "wget"
        "httpie"
        "zoxide"
      ];
      bundledPlugins = {
        summarize.enable = true;
      };

      config = {
        acp = {
          enabled = true;
          backend = "acpx";
          defaultAgent = "opencode";
          allowedAgents = [
            "opencode"
            "codex"
            "claude"
            "gemini"
            "kimi"
            "pi"
          ];
          maxConcurrentSessions = 8;
          dispatch.enabled = true;
        };

        tools.web = {
          search = {
            enabled = true;
            provider = "searxng";
            maxResults = 8;
            timeoutSeconds = 20;
          };
          fetch.enabled = true;
        };

        plugins.entries = {
          searxng.enabled = true;
          duckduckgo.enabled = true;
          exa.enabled = true;
          browser.enabled = true;
        };

        gateway = {
          mode = "local";
          auth.token = {
            source = "env";
            provider = "default";
            id = "OPENCLAW_GATEWAY_TOKEN";
          };
        };

        channels.telegram = {
          tokenFile = config.sops.secrets.openclaw_telegram_bot_token.path;
          allowFrom = [6192987588];
        };

        agents.defaults.model.primary = "github-copilot/gpt-4o";
      };
    };

    systemd.user.services.openclaw-gateway.Service.Environment = [
      "PATH=${config.home.homeDirectory}/.config/scripts:${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.cargo/bin:/run/wrappers/bin:${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${pilot}/bin:/nix/profile/bin:${config.home.homeDirectory}/.local/state/nix/profile/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:${pkgs.lib.makeBinPath [
        pkgs.nodejs_22
        pkgs.pnpm_10
        pkgs.git
        pkgs.gh
        pkgs.just
        pkgs.nix
        pkgs.ripgrep
        pkgs.fd
        pkgs.jq
        pkgs.curl
        pkgs.wget
      ]}"
    ];

    systemd.user.services.openclaw-gateway.Service.EnvironmentFile = config.sops.templates."openclaw.env".path;

    home.activation.openclawMaterializeDocuments = lib.hm.dag.entryAfter ["writeBoundary"] ''
      workspace_dir="${config.programs.openclaw.workspaceDir}"
      mkdir -p "$workspace_dir"
      rm -f "$workspace_dir/AGENTS.md" "$workspace_dir/SOUL.md" "$workspace_dir/TOOLS.md"
      install -m 0644 "${./documents}/AGENTS.md" "$workspace_dir/AGENTS.md"
      install -m 0644 "${./documents}/SOUL.md" "$workspace_dir/SOUL.md"
      install -m 0644 "${./documents}/TOOLS.md" "$workspace_dir/TOOLS.md"
    '';

    home.activation.openclawSessionReset = lib.hm.dag.entryAfter ["openclawMaterializeDocuments"] ''
      if [ -f "${config.sops.templates."openclaw.env".path}" ]; then
        token="$(sed -n 's/^OPENCLAW_GATEWAY_TOKEN=//p' "${config.sops.templates."openclaw.env".path}" | head -n1)"
        if [ -n "$token" ]; then
          ${pkgs.openclaw}/bin/openclaw gateway call --token "$token" --params '{"key":"agent:main:main"}' sessions.reset >/dev/null 2>&1 || true
        fi
      fi
    '';
  };
}
