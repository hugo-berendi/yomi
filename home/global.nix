# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  options,
  ...
}: let
  imports = [
    # {{{ flake inputs
    inputs.stylix.homeModules.stylix
    (inputs.impermanence + "/home-manager.nix")
    inputs.spicetify-nix.homeManagerModules.spicetify
    # inputs.anyrun.homeManagerModules.default
    inputs.nix-index-database.homeModules.nix-index
    inputs.sops-nix.homeManagerModules.sops
    inputs.hyprland.homeManagerModules.default
    inputs.caelestia-shell.homeManagerModules.default
    inputs.nvf.homeManagerModules.default
    inputs.nixcord.homeModules.nixcord
    # inputs.ghostty.homeModules.default
    # }}}
    # {{{ global configuration
    ./features/cli
    ./features/persistence.nix
    ../common/default.nix
    ./features/neovim
    # }}}
  ];
in {
  # Import all modules defined in modules/home-manager
  imports = builtins.attrValues outputs.homeManagerModules ++ imports;

  # {{{ Enable the home-manager and git clis
  programs = {
    home-manager.enable = true;
    git.enable = true;
  };
  # }}}
  # {{{ Set reasonable defaults for some settings
  home = lib.mkMerge [
    {
      username = lib.mkDefault "hugob";
      homeDirectory = lib.mkDefault "/home/${config.home.username}";
      stateVersion = lib.mkDefault "24.11"; # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    }
    (lib.optionalAttrs (options.home ? _nixosModuleImported) {
      _nixosModuleImported = true;
    })
  ];
  # }}}
  # {{{ Ad-hoc settings
  # Nicely reload system units when changing configs
  systemd.user.startServices = lib.mkForce "sd-switch";

  # Enable default application management
  xdg.mimeApps.enable = true;
  xdg.portal.xdgOpenUsePortal = true;

  # Tell sops-nix to use ssh keys for decrypting secrets
  sops.age.sshKeyPaths = ["/persist/state/etc/ssh/ssh_host_ed25519_key"];

  # By default the paths given by sops contain annoying %r sections
  sops.defaultSymlinkPath = "${config.home.homeDirectory}/.nix-sops";

  # {{{ Ad-hoc stylix targets
  stylix.targets.xresources.enable = true;
  # }}}
  # {{{ Xdg user directories
  # Set the xdg env vars
  xdg.enable = true;

  xdg.userDirs = {
    enable = lib.mkDefault true;
    createDirectories = lib.mkDefault true;

    desktop = null;
    templates = null;
    download = "${config.home.homeDirectory}/downloads";
    publicShare = "${config.home.homeDirectory}/public";
    music = "${config.home.homeDirectory}/media/music";
    pictures = "${config.home.homeDirectory}/media/pictures";
    videos = "${config.home.homeDirectory}/media/videos";
    documents = "${config.home.homeDirectory}/media/documents";

    extraConfig = {
      XDG_SCREENSHOTS_DIR = "${config.xdg.userDirs.pictures}/screenshots";
      XDG_PROJECTS_DIR = "${config.home.homeDirectory}/projects";
      XDG_BOOKS_DIR = "${config.home.homeDirectory}/media/books";
    };
  };

  systemd.user.tmpfiles.rules = [
    # Clean screenshots older than a week
    "d ${config.xdg.userDirs.extraConfig.XDG_SCREENSHOTS_DIR} - - - 7d"
  ];
  # }}}
}
