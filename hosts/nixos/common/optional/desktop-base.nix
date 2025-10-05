{
  lib,
  pkgs,
  ...
}: {
  # {{{ Virtualization
  programs.extra-container.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.waydroid.enable = true;
  # }}}
  # {{{ Programs
  programs.kdeconnect.enable = true;
  programs.firejail.enable = true;
  programs.dconf.enable = true;
  programs.fish.enable = true;
  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
    ];
  };
  # }}}
  # {{{ Services
  services.fwupd.enable = true;
  services.gnome.evolution-data-server.enable = true;
  services.gnome.gnome-online-accounts.enable = true;
  services.dbus.packages = [pkgs.gcr];
  # }}}
  # {{{ Environment
  environment.systemPackages = with pkgs; [
    vim
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
  };

  environment.etc."fuse.conf".text = lib.mkForce ''
    user_allow_other
    mount_max = 1000
  '';
  # }}}
}
