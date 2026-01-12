{
  description = "Your new nix config";

  inputs = {
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    # {{{ Nixpkgs instances
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
    # }}}
    # {{{ Additional package repositories
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    firefox-addons.url = "git+https://gitlab.com/rycee/nur-expressions?dir=pkgs/firefox-addons";
    firefox-addons.inputs.nixpkgs.follows = "nixpkgs";
    # }}}

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

    opencode-flake.url = "github:aodhanhayter/opencode-flake";
    nix-ai-tools.url = "github:numtide/nix-ai-tools";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # {{{ Hyprland
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

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

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    # }}}

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    korora.url = "github:adisbladis/korora";

    # }}}
    # {{{ Standalone software
    # {{{ Nightly versions of things
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    # }}}
    # {{{ Nixvim
    nixvim = {
      url = "github:nix-community/nixvim";
    };
    # }}}

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
    # }}}
    # {{{ Theming
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    base16-schemes.url = "github:tinted-theming/schemes";
    base16-schemes.flake = false;

    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
    rose-pine-hyprcursor.inputs.nixpkgs.follows = "nixpkgs";

    nixcord.url = "github:kaylorben/nixcord";
    # }}}
    ngrok.url = "github:ngrok/ngrok-nix";

    playit-nixos-module.url = "github:pedorich-n/playit-nixos-module";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [];

      flake = {
        overlays = import ./overlays;
        nixosModules = import ./modules/nixos // import ./modules/common;
        homeManagerModules = import ./modules/home-manager // import ./modules/common;

        nixosConfigurations = let
          inherit (inputs.nixpkgs) lib;
          
          specialArgs = system: {
            inherit inputs;
            outputs = self;
            upkgs = inputs.nixpkgs-unstable.legacyPackages.${system};
          };

          mkHost = {
            system,
            hostname,
          }:
            lib.nixosSystem {
              inherit system;
              specialArgs = specialArgs system;

              modules = [
                (
                  {lib, ...}: {
                    imports = lib.lists.optionals (builtins.pathExists ./home/${hostname}.nix) [
                      inputs.home-manager.nixosModules.home-manager
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

                ./hosts/nixos/${hostname}
              ];
            };
        in {
          amaterasu = mkHost {
            system = "x86_64-linux";
            hostname = "amaterasu";
          };
          tsukuyomi = mkHost {
            system = "x86_64-linux";
            hostname = "tsukuyomi";
          };
          inari = mkHost {
            system = "x86_64-linux";
            hostname = "inari";
          };
          iso = mkHost {
            system = "x86_64-linux";
            hostname = "iso";
          };
          wsl = mkHost {
            system = "x86_64-linux";
            hostname = "wsl";
          };
        };
      };

      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: let
        upkgs = inputs.nixpkgs-unstable.legacyPackages.${system};
        myPkgs = import ./pkgs {inherit pkgs upkgs;};
        
        specialArgs = {
          inherit inputs;
          outputs = self;
          inherit upkgs;
        };

        dnsPackages = (import ./dns/implementation) {
          inherit pkgs;
          extraModules = [./dns/config/common.nix];
          octodnsConfig = ./dns/config/octodns.yaml;
          nixosConfigurations = builtins.removeAttrs self.nixosConfigurations ["iso"];
        };
      in {
        packages = myPkgs // dnsPackages;

        devShells = import ./devshells (
          {
            inherit pkgs;
          }
          // specialArgs
        );

        checks = let
          hosts = ["amaterasu" "tsukuyomi" "inari"];
        in
          (builtins.listToAttrs (
            map (
              hostname: {
                name = "nixos-${hostname}";
                value = self.nixosConfigurations.${hostname}.config.system.build.toplevel;
              }
            )
            hosts
          ))
          // {
            dns-zones = dnsPackages.octodns-zones;
            dns-sync = dnsPackages.octodns-sync;
          };

        formatter = pkgs.alejandra;
      };

      # {{{ Caching and whatnot
      flake.nixConfig = {
        extra-substituters = [
          "https://nix-community.cachix.org"
          "https://smos.cachix.org"
          "https://intray.cachix.org"
          "https://playit-nixos-module.cachix.org"
        ];

        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "smos.cachix.org-1:YOs/tLEliRoyhx7PnNw36cw2Zvbw5R0ASZaUlpUv+yM="
          "intray.cachix.org-1:qD7I/NQLia2iy6cbzZvFuvn09iuL4AkTmHvjxrQlccQ="
          "playit-nixos-module.cachix.org-1:22hBXWXBbd/7o1cOnh+p0hpFUVk9lPdRLX3p5YSfRz4="
        ];
      };
      # }}}
    };
}
