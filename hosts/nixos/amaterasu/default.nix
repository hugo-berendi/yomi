# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  lib,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix
    ../common/optional/quietboot.nix
    ../common/optional/desktop/steam.nix
    ../common/optional/desktop/xdg-portal.nix
    ../common/optional/flatpak.nix
    ../common/optional/greetd.nix
    ../common/optional/pipewire.nix
    ../common/optional/wayland/hyprland.nix
    # ../common/optional/services/protonvpn.nix

    ../common/global

    ../common/users/pilot.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware
    ./boot.nix
  ];
  networking.hostName = "amaterasu";
  networking.networkmanager.enable = true;

  # {{{ A few ad-hoc hardware settings
  hardware.enableAllFirmware = true;
  hardware.opengl.enable = true;
  # hardware.opentabletdriver.enable = true;
  # hardware.keyboard.qmk.enable = true;
  powerManagement.cpuFreqGovernor = "ondemand";
  services.tlp.enable = true;
  services.thermald.enable = true;
  # }}}
  # {{{ A few ad-hoc programs
  programs.kdeconnect.enable = true;
  programs.firejail.enable = true;
  programs.extra-container.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.waydroid.enable = true;
  # virtualisation.spiceUSBRedirection.enable = true; # This was required for the vm usb passthrough tomfoolery
  # }}}
  # {{{ Ad-hoc stylix targets
  # TODO: include this on all gui hosts
  # TODO: is this useful outside of home-manager?
  stylix.targets.gtk.enable = true;
  # }}}
  # {{{ Some ad-hoc site blocking
  networking.extraHosts = let
    blacklisted = [
      # "twitter.com"
      # "www.reddit.com"
      "minesweeper.online"
    ];
    blacklist = lib.concatStringsSep "\n" (lib.forEach blacklisted (host: "127.0.0.1 ${host}"));
  in
    blacklist;
  # }}}

  services.mysql = {
    enable = true;
    package = pkgs.mysql80;
  };

  programs.dconf.enable = true;
  services.gnome.evolution-data-server.enable = true;
  services.gnome.gnome-online-accounts.enable = true;

  services.fwupd.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    gcc
    go
    python3
    python3.pkgs.pip
    rustup
    unzip
    fd
    btop
    home-manager
    dunst
    dunst
    libnotify
    ugrep
    cargo
    rustc

    envfs
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    FLAKE = "/home/hugob/Projects/nix-config";
    ENVFS_RESOLVE_ALWAYS = "1";
  };

  environment.etc."fuse.conf".text = lib.mkForce ''
    user_allow_other
    mount_max = 1000
  '';

  services.dbus.packages = [pkgs.gcr];

  programs = {
    fish.enable = true;
    nix-ld = {
      enable = true;
      package = pkgs.nix-ld-rs;

      # Sets up all the libraries to load
      libraries = with pkgs; [
        stdenv.cc.cc # commonly needed
        zlib # commonly needed
        openssl # commonly needed
      ];
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
