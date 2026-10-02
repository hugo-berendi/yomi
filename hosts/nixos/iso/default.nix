{
  modulesPath,
  pkgs,
  config,
  lib,
  outputs,
  ...
}: {
  # {{{ Imports
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"

    ../common
  ];
  # }}}

  # kagutsuchi, the key stick, is LUKS-encrypted and has no automount here:
  # scripts/live.sh unlocks it through scripts/kagutsuchi.sh, which asks for
  # its passphrase. cryptsetup and e2fsprogs come with the installer profile.

  users.users.root = {
    hashedPasswordFile = lib.mkForce null;
    openssh.authorizedKeys.keyFiles = config.users.users.${config.yomi.pilot.name}.openssh.authorizedKeys.keyFiles;
  };

  services.openssh.settings = {
    PermitRootLogin = lib.mkOverride 0 "prohibit-password";
    PasswordAuthentication = lib.mkForce false;
  };

  # {{{ Recovery environment
  boot.supportedFilesystems = ["zfs"];
  boot.zfs.forceImportRoot = false;
  networking.hostId = "8425e349"; # required by ZFS, arbitrary for a live ISO
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.zfs.package = pkgs.zfs_2_3;
  isoImage.contents = [
    {
      source = ../../..;
      target = "/yomi";
    }
  ];
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";
  environment.etc."issue".text = lib.mkAfter ''
    Run yomi-recover for SSD backup, installation and recovery.
    The bundled checkout is at /iso/yomi. Unlock kagutsuchi from the menu.
  '';
  environment.etc."yomi-recovery-iso".text = "1\n";
  # }}}

  # {{{ Testing AMD SRSO mitigation workaround (srso_alias_safe_ret panic on AZW EQ/EQ)
  hardware.cpu.amd.updateMicrocode = true;
  specialisation.beelink-rescue.configuration = {
    system.nixos.tags = ["beelink-rescue"];
    boot.kernelParams = [
      "spec_rstack_overflow=ibpb"
      "maxcpus=1"
      "processor.max_cstate=1"
      "idle=nomwait"
      "amd_pstate=disable"
    ];
  };
  # }}}

  environment.systemPackages = let
    cloneConfig = pkgs.writeShellScriptBin "liftoff" ''
      git clone https://github.com/hugo-berendi/yomi.git
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
      outputs.packages.${pkgs.stdenv.hostPlatform.system}.yomi-recover

      # ZFS + storage diagnostics
      config.boot.zfs.package
      smartmontools
      nvme-cli
      hdparm
      sdparm
      parted
      gptfdisk
      pciutils
      usbutils
      lsscsi
    ];

  environment.defaultPackages = [];

  yomi.wireless.enable = false;
}
