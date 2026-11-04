{
  config,
  pkgs,
  inputs,
  upkgs,
  ...
}: let
  pilot = config.yomi.pilot.name;
  port = config.yomi.ports.t3code;
  # Forge CLIs t3code's Forgejo/Gitea integration looks for. tea needs 0.16+, stable has 0.14.
  forgeClis = [upkgs.forgejo-cli upkgs.tea];
  package = import ../../../../pkgs/t3code-tools.nix {inherit pkgs inputs;};
in {
  imports = [inputs.t3code-nix.nixosModules.default ./t3code-vm ./t3code-repair.nix];
  services.t3code = {
    enable = true;
    user = pilot;
    inherit port;
    providerPackages = package.providers;
    extraPackages = [package] ++ forgeClis;
    memory.enable = true;
    oidc = {
      enable = true;
      issuer = config.yomi.cloudflared.at.pocket-id.url;
      origin = config.yomi.nginx.at.t3code.url;
      # Pocket ID restricts this client to the t3code group.
      clientId = "2db66a5a-664a-4938-a2d1-15815ec7c1d2";
      clientSecretFile = config.sops.secrets.t3code_oidc_client_secret.path;
    };
  };
  sops.secrets.t3code_oidc_client_secret = {
    sopsFile = ../secrets.yaml;
    owner = pilot;
  };
  yomi.t3codeVm = {
    enable = true;
    toolingPackage = package;
    providerInstances = {
      codex = {
        driver = "codex";
        enabled = true;
      };
      claudeAgent = {
        driver = "claudeAgent";
        enabled = true;
      };
      opencode = {
        driver = "opencode";
        enabled = true;
        config.binaryPath = "/opt/t3code-tools/bin/opencode2";
      };
      acpRegistry_copilot = {
        driver = "acpRegistry";
        enabled = true;
        config = {
          source = "local";
          commandPath = "/opt/t3code-tools/bin/copilot";
          commandArgs = ["--acp"];
        };
      };
    };
  };
  yomi.nginx.at.t3code.port = port;

  home-manager.users.${pilot} = {config, ...}: {
    home.packages = [package] ++ forgeClis;

    yomi.persistence.at.state.apps.t3code.directories = [
      "${config.home.homeDirectory}/.t3"
      "${config.home.homeDirectory}/.local/state/t3code-vm"
    ];
  };
}
