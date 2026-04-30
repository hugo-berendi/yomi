{
  modulesPath,
  pkgs,
  lib,
  ...
}: {
  # {{{ Imports
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"

    ../common
  ];
  # }}}

  # {{{ Automount kagutsuchi
  fileSystems."/kagutsuchi" = {
    device = "/dev/disk/by-uuid/9e2345c6-7c31-4a76-97d8-73adc71c1a19";
    fsType = "ext4";
    neededForBoot = true;
    options = [
      "nofail"
      "x-systemd.automount"
    ];
  };
  # }}}

  users.users.root.hashedPasswordFile = lib.mkForce null;

  environment.systemPackages = let
    cloneConfig = pkgs.writeShellScriptBin "liftoff" ''
      git clone https://github.com:hugo-berendi/yomi.git
      cd yomi
    '';
  in
    with pkgs; [
      git
      neovim
      just
      nixos-install-tools
      disko
      cloneConfig
    ];

  environment.defaultPackages = [];

  boot.initrd.systemd.enable = lib.mkForce false;

  yomi.wireless.enable = false;

  # Fast but bad compression
  # isoImage.squashfsCompression = "gzip -Xcompression-level 1";
}
