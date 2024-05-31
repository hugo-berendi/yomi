# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{ inputs, outputs, lib, config, pkgs, ... }: {
  # You can import other home-manager modules here
  imports = [
    ./features/desktop/zathura.nix
    ./features/desktop/spotify.nix
    ./features/desktop/obsidian.nix
    ./features/desktop/firefox
    ./features/desktop/discord
    ./features/cli/productivity
    ./features/cli/pass.nix
    ./features/cli/nix-index.nix
    ./features/cli/catgirl.nix
    ./features/cli/lazygit.nix
    ./features/wayland/hyprland
    ./features/desktop/kitty
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  home = {
    username = "hugob";
    homeDirectory = "/home/hugob";
    stateVersion =
      "23.11"; # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    file = { };
    sessionVariables = { EDITOR = "nvim"; };
    packages = with pkgs; [
      kitty
      neovide
      zoxide
      nwg-bar
      nwg-look
      thunderbird
      thefuck
      eza
      nodejs
      nixfmt-classic
      zathura
      sxiv
      mpv
    ];
  };

  # Enable home-manager and git
  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      userName = "hugo-berendi";
      userEmail = "hugo.berendi@outlook.de";
      aliases = { rp = "pull --rebase"; };
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

}
