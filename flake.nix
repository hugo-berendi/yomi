{
  description = "Your new nix config";

  inputs = {
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    # {{{ Nixpkgs instances
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # }}}
    # {{{ Additional package repositories
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Firefox addons
    firefox-addons.url = "git+https://gitlab.com/rycee/nur-expressions?dir=pkgs/firefox-addons";
    firefox-addons.inputs.nixpkgs.follows = "nixpkgs";
    # }}}

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

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
    # }}}

    ghostty-pkg = {
      url = "github:ghostty-org/ghostty";
    };

    # {{{ AGS
    ags.url = "github:Aylur/ags";
    # }}}

    # {{{ Yazi flakes
    yazi.url = "github:sxyazi/yazi";
    # }}}

    # {{{ Nix-related tooling
    nixarr.url = "github:rasmus-kirk/nixarr";

    declarative-jellyfin.url = "github:Sveske-Juice/declarative-jellyfin";
    declarative-jellyfin.inputs.nixpkgs.follows = "nixpkgs";

    # {{{ Storage
    impermanence.url = "github:nix-community/impermanence";

    # Declarative partitioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    # }}}

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    korora.url = "github:adisbladis/korora";

    authentik-nix = {
      url = "github:nix-community/authentik-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

    anyrun-hyprwin = {
      url = "github:uttarayan21/anyrun-hyprwin";
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

    # Spotify client with theming support
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
    # }}}
    # {{{ Theming
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix.inputs.home-manager.follows = "home-manager";

    base16-schemes.url = "github:tinted-theming/schemes";
    base16-schemes.flake = false;

    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
    rose-pine-hyprcursor.inputs.nixpkgs.follows = "nixpkgs";

    nixcord.url = "github:kaylorben/nixcord";
    # }}}
    ngrok.url = "github:ngrok/ngrok-nix";

    playit-nixos-module.url = "github:pedorich-n/playit-nixos-module";

    opencode-flake.url = "github:aodhanhayter/opencode-flake";
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
          myPkgs = import ./pkgs {inherit pkgs upkgs;};
        in
          myPkgs
          // (import ./dns/implementation) {
            inherit pkgs;
            extraModules = [./dns/config/common.nix];
            octodnsConfig = ./dns/config/octodns.yaml;
            nixosConfigurations = builtins.removeAttrs self.nixosConfigurations ["iso"];
          }
      );
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
          system = "x86_64-linux";
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
      "https://playit-nixos-module.cachix.org"
    ];

    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      # "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
      "smos.cachix.org-1:YOs/tLEliRoyhx7PnNw36cw2Zvbw5R0ASZaUlpUv+yM="
      "intray.cachix.org-1:qD7I/NQLia2iy6cbzZvFuvn09iuL4AkTmHvjxrQlccQ="
      "playit-nixos-module.cachix.org-1:22hBXWXBbd/7o1cOnh+p0hpFUVk9lPdRLX3p5YSfRz4="
    ];
  };
  # }}}
}
