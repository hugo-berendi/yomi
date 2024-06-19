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
    ../common/optional/flatpak.nix

    ../common/global

    ../common/users/pilot.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware
    ./boot.nix
    # {{{ disk formatting using disko (only enable on new install)
    # ./filesystems
    # ./services/zfs.nix
    # }}}
  ];
  programs.dconf.enable = true;

  networking.hostName = "amaterasu";
  networking.networkmanager.enable = true;

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;
    };
  };

  # TODO: Remove in the future:
  programs.hyprland.enable = true;

  # Enable the sddm.
  services.displayManager.sddm = {
    enable = true;
    theme = "rose-pine";
    wayland = {enable = true;};
  };

  fonts.packages = with pkgs.unstable; [maple-mono-NF (nerdfonts.override {fonts = ["Recursive"];})];

  xdg.portal = {
    enable = true;
    configPackages = [pkgs.xdg-desktop-portal-hyprland];
    extraPortals = [pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk];
  };

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
    bat
    unzip
    starship
    tmux
    fd
    btop
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit
    fishPlugins.hydro
    fzf
    fishPlugins.grc
    grc
    (callPackage ./sddm-rose-pine.nix {})
    (callPackage ./fonts.nix {})
    home-manager
    dunst
    dunst
    libnotify
    tofi
    rofi
    hyprland
    ugrep
    cargo
    rustc

    envfs
  ];

  system.activationScripts = {
    symlinks.text = lib.mkDefault ''
      ln -s /run/current-system/sw/bin/fish /usr/bin/fish
    '';
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    FLAKE = "/home/hugob/dotfiles/nix-config";
    ENVFS_RESOLVE_ALWAYS = "1";
  };

  environment.etc."fuse.conf".text = lib.mkForce ''
    user_allow_other
    mount_max = 1000
  '';

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

  hardware = {opengl.enable = true;};

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
