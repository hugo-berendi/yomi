# See the wiki for more details https://wiki.nixos.org/wiki/Creating_a_NixOS_live_CD
#
# Can be built with
# nix build .#nixosConfigurations.iso.config.system.build.isoImage
{
  modulesPath,
  pkgs,
  lib,
  ...
}: {
  # {{{ Imports
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"

    ../common/global
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

  # Tell sops-nix to use the hermes keys for decrypting secrets
  sops.age.sshKeyPaths = lib.mkForce ["/kagutsuchi/secrets/kagutsuchi/ssh_host_ed25519_key"];

  environment.systemPackages = let
    cloneConfig = pkgs.writeShellScriptBin "liftoff" ''
      git clone https://github.com:hugo-berendi/yomi.git
      cd yomi
    '';
  in
    with pkgs; [
      git
      sops # Secret editing
      neovim # Text editor
      cloneConfig # Clones my nixos config from github
    ];

  boot.initrd.systemd.enable = lib.mkForce false;

  # Fast but bad compression
  # isoImage.squashfsCompression = "gzip -Xcompression-level 1";
}
