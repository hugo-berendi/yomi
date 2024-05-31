# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{ inputs, outputs, lib, config, pkgs, ... }:
let
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
    ./features/wayland/hyprland
    ./features/desktop/kitty
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

  satellite = {
    monitors = [{
      name = "eDP-1";
      width = 1920;
      height = 1080;
    }];
  };

  # TODO: Put styling somewhere else
  # Stylix styling

  stylix = {
    base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine-moon.yaml";
    image = ../common/themes/wallpapers/something-beautiful-in-nature.jpg;
  };

}

# RecMonoLinear Nerd Font
