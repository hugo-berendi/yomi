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
    sessionVariables = {EDITOR = "nvim";};
    packages = with pkgs; [
      sops
      upkgs.alejandra
      upkgs.nh
      upkgs.nix-output-monitor
      upkgs.nvd
    ];
  };

  home.persistence."/persist/home/${config.home.username}" = lib.mkForce {};

  sops.age.sshKeyPaths = lib.mkForce ["/etc/ssh/ssh_host_ed25519_key"];

  xdg.userDirs.enable = false;
}
