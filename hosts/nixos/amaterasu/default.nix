# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  lib,
  pkgs,
  config,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    ../common/global
    ../common/users/pilot.nix

    ../common/optional/bluetooth.nix
    ../common/optional/greetd.nix
    ../common/optional/oci.nix
    ../common/optional/quietboot.nix
    ../common/optional/yubikey.nix

    ../common/optional/desktop
    ../common/optional/desktop/steam.nix
    ../common/optional/wayland/hyprland.nix

    ../common/optional/services/nginx.nix
    ../common/optional/services/syncthing.nix

    # ./services/snapper.nix # throws wierd error

    ./hardware
    ./filesystems
    ../common/optional/grub.nix
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";

  # {{{ Machine ids
  networking.hostName = "amaterasu";
  environment.etc.machine-id.text = "08357db3540c4cd2b76d4bb7f825ec88";
  # }}}
  # {{{ Tailscale internal IP DNS records
  yomi.dns.records = [
    {
      at = config.networking.hostName;
      type = "A";
      value = "100.127.234.94";
    }
    {
      at = config.networking.hostName;
      type = "AAAA";
      value = "fd7a:115c:a1e0::501:ea5f";
    }
  ];
  # }}}
  # {{{ A few ad-hoc programs
  programs.kdeconnect.enable = true;
  programs.firejail.enable = true;
  programs.extra-container.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.waydroid.enable = true;
  # virtualisation.spiceUSBRedirection.enable = true; # This was required for the vm usb passthrough tomfoolery
  # }}}

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
    go
    python3
    python3.pkgs.pip
    rustup
    unzip
    fd
    btop
    home-manager
    libnotify
    ugrep
    cargo
    rustc

    gcc13

    envfs
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    FLAKE = "/home/hugob/projects/yomi";
    ENVFS_RESOLVE_ALWAYS = "1";
    # LD_LIBRARY_PATH = lib.mkForce "${pkgs.stdenv.cc.cc.lib}/lib";
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

  yomi.pilot.name = "hugob";
}
