{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  # {{{ Imports
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ../common
  ];
  # }}}

  system.stateVersion = "24.05";

  yomi.pilot.name = "hugob";
  yomi.machine.graphical = false;
  yomi.machine.gaming = false;
  yomi.machine.interactible = true;

  # {{{ Disable features not applicable to WSL
  yomi.wireless.enable = false;
  boot.initrd.systemd.enable = lib.mkForce false;
  systemd.oomd.enable = lib.mkForce false;
  zramSwap.enable = lib.mkForce false;
  # }}}

  # {{{ WSL configuration
  wsl.enable = true;
  wsl.defaultUser = "hugob";
  wsl.startMenuLaunchers = true;
  wsl.useWindowsDriver = true;

  wsl.wslConf.automount.root = "/mnt";
  wsl.wslConf.automount.options = "metadata,umask=22,fmask=11";
  wsl.wslConf.interop.appendWindowsPath = true;
  wsl.wslConf.network.generateHosts = false;
  wsl.wslConf.network.generateResolvConf = true;
  # }}}

  # {{{ Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
  };
  users.users.${config.yomi.pilot.name}.extraGroups = ["docker"];
  # }}}

  # {{{ Development tools
  environment.systemPackages = with pkgs; [
    docker-compose
    gcc
    gnumake
    cmake
    pkg-config
    openssl
    git
    curl
    wget
    unzip
    file
  ];
  # }}}

  # {{{ VS Code Server support
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      curl
      icu
    ];
  };
  # }}}

  # {{{ Machine ids
  networking.hostName = "wsl";
  environment.etc.machine-id.text = "08357db3540c4cd2b76d4bb7f825ec89";
  # }}}

  # {{{ Sops configuration for WSL (no persistence)
  sops.age.sshKeyPaths = lib.mkForce ["/etc/ssh/ssh_host_ed25519_key"];
  # }}}
}
