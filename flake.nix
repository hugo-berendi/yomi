{
  #
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-24.05";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # {{{ Hyprland
    hyprland = {
      url = "github:hyprwm/Hyprland"; # ?ref=v0.42.0";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Hyprland plugins
    pyprland.url = "github:hyprland-community/pyprland";
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
    # neovim-nightly-overlay.inputs.nixpkgs.follows = "nixpkgs";
    # }}}
    # {{{ Nixvim
    nixvim = {
      url = "github:nix-community/nixvim";
      # If using a stable channel you can use `url = "github:nix-community/nixvim/nixos-<version>"`
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

    # {{{ anyrun
    anyrun = {
      url = "github:Kirottu/anyrun";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    anyrun-nixos-options = {
      url = "github:n3oney/anyrun-nixos-options";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    anyrun-rbw = {
      url = "github:uttarayan21/anyrun-rbw";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    anyrun-plugins = {
      url = "github:wuliuqii/anyrun-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # anyrun-spotify = {
    #   url = "github:hugo-berendi/anyrun-spotify";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # }}}

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    miros.url = "github:prescientmoon/miros";
    miros.inputs.nixpkgs.follows = "nixpkgs";

    # Spotify client with theming support
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
    # }}}
    # {{{ Theming
    darkmatter-grub-theme.url = "gitlab:VandalByte/darkmatter-grub-theme";
    darkmatter-grub-theme.inputs.nixpkgs.follows = "nixpkgs";

    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix.inputs.home-manager.follows = "home-manager";

    base16-schemes.url = "github:tinted-theming/schemes";
    base16-schemes.flake = false;

    nixos-hardware.url = "github:nixos/nixos-hardware";

    nix-mineral = {
      url = "github:cynicsketch/nix-mineral"; # Refers to the main branch and is updated to the latest commit when you use "nix flake update"
      # url = "github:cynicsketch/nix-mineral/v0.1.6-alpha" # Refers to a specific tag and follows that tag until you change it
      # url = "github:cynicsketch/nix-mineral/cfaf4cf15c7e6dc7f882c471056b57ea9ea0ee61" # Refers to a specific commit and follows that until you change it
      flake = false;
    };

    nixcord.url = "github:kaylorben/nixcord";
    # }}}
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    # {{{ Common helpers
    inherit (self) outputs;
    forAllSystems = nixpkgs.lib.genAttrs [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    specialArgs = system: {
      inherit inputs outputs;

      upkgs = inputs.nixpkgs-unstable.legacyPackages.${system};
      opkgs = inputs.nixpkgs-old.legacyPackages.${system};
    };
  in
    # }}}
    {
      # {{{ Packages
      # Accessible through 'nix build', 'nix shell', etc
      packages = forAllSystems (
        system: let
          pkgs = nixpkgs.legacyPackages.${system};
          upkgs = inputs.nixpkgs-unstable.legacyPackages.${system};
          opkgs = inputs.nixpkgs-old.legacyPackages.${system};
          myPkgs = import ./pkgs {inherit pkgs upkgs opkgs;};
        in
          myPkgs
          // {
            octodns = upkgs.octodns.withProviders (_ps: [myPkgs.octodns-cloudflare]);
          }
          // (import ./dns/pkgs.nix) {inherit pkgs self system;}
      );
      # }}}
      # {{{ Pre Commit Hooks
      checks = forAllSystems (system: {
        pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
            deadnix.enable = true;
            flake-checker.enable = true;
          };
        };
      });

      # }}}
      # {{{ Bootstrapping and other pinned devshells
      # Accessible through 'nix develop'
      devShells = forAllSystems (
        system: let
          pkgs = nixpkgs.legacyPackages.${system};
          args =
            {
              inherit pkgs;
            }
            // specialArgs system;
        in
          import ./devshells args
      );
      # }}}
      # {{{ Overlays and modules
      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays;

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
              # {{{ Import home manager
              (
                {lib, ...}: {
                  imports = lib.lists.optionals (builtins.pathExists ./home/${hostname}.nix) [
                    home-manager.nixosModules.home-manager
                    {
                      home-manager.users.pilot = ./home/${hostname}.nix;
                      home-manager.extraSpecialArgs =
                        specialArgs system
                        // {
                          inherit hostname;
                        };
                      home-manager.useUserPackages = true;
                      home-manager.backupFileExtension = "backy";

                      stylix.homeManagerIntegration.followSystem = false;
                      stylix.homeManagerIntegration.autoImport = false;
                    }
                  ];
                }
              )
              # }}}

              ./hosts/nixos/${hostname}
            ];
          };
      in {
        amaterasu = nixos {
          system = "x86_64-linux";
          hostname = "amaterasu";
        };
        tsukuyomi = nixos {
          system = "x86_64-linux";
          hostname = "tsukuyomi";
        };
        inari = nixos {
          system = "aarch64-linux";
          hostname = "inari";
        };
        iso = nixos {
          system = "x86_64-linux";
          hostname = "iso";
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
