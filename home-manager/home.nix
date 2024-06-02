# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  upkgs,
  ...
}: let
  imports = [
    # {{{ flake inputs
    inputs.stylix.homeManagerModules.stylix
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.spicetify-nix.homeManagerModules.spicetify
    inputs.anyrun.homeManagerModules.default
    inputs.nix-index-database.hmModules.nix-index
    inputs.sops-nix.homeManagerModules.sops

    # {{{ self management
    # NOTE: using `pkgs.system` before `module.options` is evaluated
    # leads to infinite recursion!
    inputs.intray.homeManagerModules.x86_64-linux.default
    inputs.smos.homeManagerModules.x86_64-linux.default
    # }}}
    # }}}

    ./features/desktop/firefox
    ./features/desktop/discord
    # ./features/cli/productivity
    # ./features/cli/pass.nix
    # ./features/cli/nix-index.nix
    # ./features/cli/catgirl.nix
    # ./features/cli/lazygit.nix
    ./features/cli/git.nix
    ./features/cli/ssh.nix
    ./features/wayland/hyprland
    ./features/desktop/spotify.nix
    ./features/desktop/obsidian.nix
    ./features/desktop/zathura.nix
    ./features/desktop

    ../common/fonts.nix
  ];
in {
  # Import all modules defined in modules/home-manager
  imports = builtins.attrValues outputs.homeManagerModules ++ imports;

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
      permittedInsecurePackages = [
        "electron-25.9.0"
      ];
    };
  };

  home = {
    username = "hugob";
    homeDirectory = "/home/hugob";
    stateVersion = "23.11"; # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    file = {};
    sessionVariables = {EDITOR = "nvim";};
    packages = [
      pkgs.zoxide
      pkgs.nwg-bar
      pkgs.nwg-look
      pkgs.thunderbird
      pkgs.thefuck
      pkgs.eza
      pkgs.nodejs
      pkgs.zathura
      pkgs.sxiv
      pkgs.mpv
      pkgs.unityhub
      upkgs.alejandra # nix formatter
      upkgs.neovim
      upkgs.neovide
      upkgs.nh
      upkgs.nix-output-monitor
      upkgs.nvd
    ];
  };

  # Enable home-manager and git
  programs = {
    home-manager.enable = true;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  xdg.userDirs.extraConfig.XDG_PROJECTS_DIR = "/home/hugob/Documents";

  satellite = {
    monitors = [
      {
        name = "eDP-1";
        width = 1920;
        height = 1080;
      }
    ];
  };

  # TODO: Put styling somewhere else
  # Stylix styling

  stylix = {
    base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine-moon.yaml";
    image = ../common/themes/wallpapers/something-beautiful-in-nature.jpg;

    cursor = {
      package = upkgs.rose-pine-cursor;
      name = "BreezeX-RoséPine";
    };
  };
}
# RecMonoLinear Nerd Font

