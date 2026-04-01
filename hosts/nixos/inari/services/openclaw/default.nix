{
  config,
  inputs,
  ...
}: let
  pilot = config.yomi.pilot.name;
in {
  nixpkgs.overlays = [inputs.nix-openclaw.overlays.default];

  home-manager.users.${pilot} = {
    config,
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
    '';

    programs.openclaw = {
      enable = true;
      toolNames = [
        "nodejs_22"
        "pnpm_10"
        "git"
        "gh"
        "just"
        "nix"
        "ripgrep"
        "fd"
        "jq"
        "curl"
        "wget"
      ];
      documents = ./documents;

      bundledPlugins = {
        summarize.enable = true;
      };

      config = {
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
  };
}
