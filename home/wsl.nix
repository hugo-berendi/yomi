{
  pkgs,
  upkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./global.nix
  ];

  yomi.toggles.isServer.enable = false;
  yomi.dev.enable = true;

  home = {
    file = {};
    sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "wslview";
    };
    packages = with pkgs; [
      # {{{ Nix tooling
      sops
      upkgs.alejandra
      upkgs.nh
      upkgs.nix-output-monitor
      upkgs.nvd
      # }}}

      # {{{ Development languages & runtimes
      nodejs_22
      python3
      go
      rustup
      # }}}

      # {{{ Development tools
      lazydocker
      dive
      # }}}

      # {{{ WSL utilities
      wslu
      # }}}
    ];
  };

  home.persistence."/persist/home/${config.home.username}" = lib.mkForce {};

  sops.age.sshKeyPaths = lib.mkForce ["/etc/ssh/ssh_host_ed25519_key"];

  xdg.userDirs.enable = false;

  xdg.portal.xdgOpenUsePortal = lib.mkForce false;

  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
  };

  services.ssh-agent.enable = true;
}
