# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
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
    inputs.hyprland.homeManagerModules.default
    inputs.ags.homeManagerModules.default
    # inputs.nixvim.homeManagerModules.nixvim
    inputs.nixcord.homeManagerModules.nixcord
    # {{{ self management
    # NOTE: using `pkgs.system` before `module.options` is evaluated
    # leads to infinite recursion!
    inputs.intray.homeManagerModules.x86_64-linux.default
    inputs.smos.homeManagerModules.x86_64-linux.default
    # }}}
    # }}}
    # {{{ global configuration
    ./features/cli
    ./features/persistence.nix
    ../common
    # }}}
  ];
in {
  # Import all modules defined in modules/home-manager
  imports = builtins.attrValues outputs.homeManagerModules ++ imports;

  # {{{ Nixpkgs
  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      outputs.overlays.old-packages
      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default
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
  # }}}
  # {{{ Enable the home-manager and git clis
  programs = {
    home-manager.enable = true;
    git.enable = true;
  };
  # }}}
  # {{{ Set reasonable defaults for some settings
  home = {
    username = lib.mkDefault "hugob";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "24.05"; # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  };
  # }}}
  # {{{ Ad-hoc settings
  # Nicely reload system units when changing configs
  systemd.user.startServices = lib.mkForce "sd-switch";

  # Tell sops-nix to use ssh keys for decrypting secrets
  sops.age.sshKeyPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];

  # By default the paths given by sops contain annoying %r sections
  sops.defaultSymlinkPath = "${config.home.homeDirectory}/.nix-sops";

  # {{{ Ad-hoc stylix targets
  stylix.targets.xresources.enable = true;
  # }}}
  # }}} # }}}
  # {{{ Xdg user directories
  # Set the xdg env vars
  xdg.enable = true;

  xdg.userDirs = {
    enable = lib.mkDefault true;
    createDirectories = lib.mkDefault false;

    desktop = "${config.home.homeDirectory}/Desktop";
    templates = null;
    download = "${config.home.homeDirectory}/Downloads";
    publicShare = "${config.home.homeDirectory}/Public";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
    documents = "${config.home.homeDirectory}/Documents";

    extraConfig.XDG_SCREENSHOTS_DIR = "${config.xdg.userDirs.pictures}/Screenshots";
    extraConfig.XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projects";
  };
  # }}}
}
