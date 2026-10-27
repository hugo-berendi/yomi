{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../global.nix
  ];

  home = {
    sessionVariables = {
      BROWSER = "wslview";
    };
    packages = with pkgs; [
      # {{{ Nix tooling
      just
      alejandra
      # }}}

      # {{{ Development languages & runtimes
      python3
      go
      cargo
      rustc
      # }}}

      # {{{ Development tools
      lazydocker
      dive
      # }}}

      # {{{ WSL utilities
      wsl-open
      # }}}
    ];
  };

  yomi.persistence.enable = lib.mkForce false;

  sops.age.sshKeyPaths = lib.mkForce ["/etc/ssh/ssh_host_ed25519_key"];

  xdg.userDirs.enable = false;

  xdg.portal.xdgOpenUsePortal = lib.mkForce false;

  # programs.ssh, AddKeysToAgent and services.ssh-agent now come from
  # features/cli/ssh.nix, which every host imports.
}
