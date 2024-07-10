{
  #
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-23.11";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # {{{ Hyprland
    hyprland = {
      url = "github:hyprwm/Hyprland";
    };

    # Hyprland plugins
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    hy3 = {
      url = "github:outfoxxed/hy3";
      inputs.hyprland.follows = "hyprland";
    };
    # }}}

    # {{{ AGS
    ags.url = "github:Aylur/ags";
    # }}}

    # {{{ Yazi flakes
    yazi.url = "github:sxyazi/yazi";
    # }}}

    # Firefox addons
    firefox-addons.url = "git+https://gitlab.com/rycee/nur-expressions?dir=pkgs/firefox-addons";
    firefox-addons.inputs.nixpkgs.follows = "nixpkgs";
    # }}}
    # {{{ Nix-related tooling
    # {{{ Storage
    impermanence.url = "github:nix-community/impermanence";

    # Declarative partitioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # }}}

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    korora.url = "github:adisbladis/korora";
    # }}}
    # {{{ Standalone software
    # {{{ Nightly versions of things
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    neovim-nightly-overlay.inputs.nixpkgs.follows = "nixpkgs";
    # }}}
    # {{{ Nixvim
    nixvim = {
      url = "github:nix-community/nixvim";
      # If you are not running an unstable channel of nixpkgs, select the corresponding branch of nixvim.
      # url = "github:nix-community/nixvim/nixos-24.05";

      inputs.nixpkgs.follows = "nixpkgs";
    };
    # }}}
    # {{{ Self management
    # Smos
    smos.url = "github:NorfairKing/smos";
    smos.inputs.nixpkgs.url = "github:NixOS/nixpkgs/b8dd8be3c790215716e7c12b247f45ca525867e2";
    # REASON: smos fails to build this way
    # smos.inputs.nixpkgs.follows = "nixpkgs";
    # smos.inputs.home-manager.follows = "home-manager";

    # Intray
    intray.url = "github:NorfairKing/intray";
    intray.inputs.nixpkgs.url = "github:NixOS/nixpkgs/cf28ee258fd5f9a52de6b9865cdb93a1f96d09b7";
    # intray.inputs.home-manager.follows = "home-manager";
    # }}}

    anyrun.url = "github:Kirottu/anyrun";
    anyrun.inputs.nixpkgs.follows = "nixpkgs";

    nix-flatpak.url = "github:gmodena/nix-flatpak";
    nix-flatpak.inputs.nixpkgs.follows = "nixpkgs";

    miros.url = "github:prescientmoon/miros";
    miros.inputs.nixpkgs.follows = "nixpkgs";

    # Spotify client with theming support
    spicetify-nix.url = "github:the-argus/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
    # }}}
    # {{{ Theming
    darkmatter-grub-theme.url = "gitlab:VandalByte/darkmatter-grub-theme";
    darkmatter-grub-theme.inputs.nixpkgs.follows = "nixpkgs";

    stylix.url = "github:danth/stylix/a33d88cf8f75446f166f2ff4f810a389feed2d56";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix.inputs.home-manager.follows = "home-manager";

    base16-schemes.url = "github:tinted-theming/schemes";
    base16-schemes.flake = false;
    # }}}
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    # Main username
    pilot = "hugob";

    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;

    specialArgs = system: {
      inherit inputs outputs;
    };
  in {
    nixpkgs.config.permittedInsecurePackages = [
      "electron-25.9.0"
    ];
    # {{{ Packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        import ./pkgs {inherit pkgs;}
    );
    # }}}
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter =
      forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # {{{ Bootstrapping and other pinned devshells
    # Accessible through 'nix develop'
    devShells =
      forAllSystems
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        args = {inherit pkgs;} // specialArgs system;
      in
        import ./devshells args);
    # }}}
    # {{{ Overlays and modules
    # Custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    # Reusable nixos modules
    nixosModules = import ./modules/nixos // import ./modules/common;

    # Reusable home-manager modules
    homeManagerModules = import ./modules/home-manager // import ./modules/common;
    # }}}
    # {{{ Nixos
    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = let
      nixos = {
        system,
        hostname,
      }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = specialArgs system;

          modules = [
            home-manager.nixosModules.home-manager
            {
              home-manager.users.hugob = import ./home/${hostname}.nix;
              home-manager.extraSpecialArgs = specialArgs system // {inherit hostname;};
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "back";

              stylix.homeManagerIntegration.followSystem = false;
              stylix.homeManagerIntegration.autoImport = false;
            }

            ./hosts/nixos/${hostname}
          ];
        };
    in {
      amaterasu = nixos {
        system = "x86_64-linux";
        hostname = "amaterasu";
      };
      inari = nixos {
        system = "aarch64-linux";
        hostname = "inari";
      };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = let
      mkHomeConfig = {
        system,
        hostname,
      }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = specialArgs system // {inherit hostname;};
          modules = [./home/${hostname}.nix];
        };
    in {
      "${pilot}@amaterasu" = mkHomeConfig {
        system = "x86_64-linux";
        hostname = "amaterasu";
      };
      "${pilot}@inari" = mkHomeConfig {
        system = "aarch64-linux";
        hostname = "inari";
      };
    };
  };

  # {{{ Caching and whatnot
  # TODO: persist trusted substituters file
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      # "https://anyrun.cachix.org"
      "https://smos.cachix.org"
      "https://intray.cachix.org"
    ];

    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      # "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
      "smos.cachix.org-1:YOs/tLEliRoyhx7PnNw36cw2Zvbw5R0ASZaUlpUv+yM="
      "intray.cachix.org-1:qD7I/NQLia2iy6cbzZvFuvn09iuL4AkTmHvjxrQlccQ="
    ];
  };
  # }}}
}
