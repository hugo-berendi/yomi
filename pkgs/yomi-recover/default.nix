{
  lib,
  writeShellApplication,
  python3,
  age,
  age-plugin-yubikey,
  zstd,
  zfs_2_3,
  util-linux,
  gptfdisk,
  dosfstools,
  disko,
  nixos-install-tools,
  nix,
  git,
  gnutar,
  clevis,
  tpm2-tools,
  rsync,
  openssh,
  cryptsetup,
  path,
  parted,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  gawk,
  pkgs,
  cifs-utils,
}: let
  # Prebuild the locked Disko layout and its dependencies. A recovery ISO must
  # not need to fetch a compiler merely to partition a disk without networking.
  diskoLib = import disko.src {inherit lib;};
  layout = import ./layout.nix {};
  recoveryPkgs = pkgs // {zfs = zfs_2_3;};
  destroy = diskoLib._cliDestroy layout recoveryPkgs;
  format = diskoLib._cliFormat layout recoveryPkgs;
in
  writeShellApplication {
    name = "yomi-recover";
    runtimeInputs = [
      python3
      age
      age-plugin-yubikey
      zstd
      zfs_2_3
      util-linux
      gptfdisk
      dosfstools
      disko
      nixos-install-tools
      nix
      git
      gnutar
      clevis
      tpm2-tools
      rsync
      openssh
      cryptsetup
      parted
      coreutils
      findutils
      gnugrep
      gnused
      gawk
      cifs-utils
    ];
    text = ''
      # The installation image logs in as nixos, with passwordless sudo.
      if [[ -f /etc/yomi-recovery-iso && $EUID -ne 0 ]]; then
        exec /run/wrappers/bin/sudo "$0" "$@"
      fi
      # Disko's file-based evaluator imports <nixpkgs>; a cold ISO has no channel.
      export NIX_PATH="nixpkgs=${path}''${NIX_PATH:+:$NIX_PATH}"
      export YOMI_DISKO_DESTROY="${destroy}"
      export YOMI_DISKO_FORMAT="${format}"
      exec python3 ${./recover.py} "$@"
    '';
    meta = {
      description = "Yomi disk backup, migration and recovery wizard";
      platforms = lib.platforms.linux;
      mainProgram = "yomi-recover";
    };
  }
