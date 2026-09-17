{
  description = "Yomi: declarative NixOS and Home Manager configurations";

  # {{{ Caching and whatnot
  # Two constraints force the shape of this block. It has to be a top-level
  # attribute, because nix reads `nixConfig` off the flake file rather than off
  # the `outputs` attrset -- declaring it through flake-parts'
  # `flake.nixConfig` was silently ignored, and every `--accept-flake-config`
  # in the justfile had nothing to accept. And the values have to be literal
  # lists, because nix refuses to force a thunk here ("setting
  # 'extra-substituters' is a thunk"), so this cannot `import`
  # common/caches.nix the way hosts/nixos/common/nix.nix does.
  #
  # Keep in sync with common/caches.nix. That file is what configured hosts
  # actually use; this copy only matters where yomi's own nix.conf is not in
  # play yet, which in practice means `nixos-install` from the ISO.
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://smos.cachix.org"
      "https://intray.cachix.org"
      "https://playit-nixos-module.cachix.org"
      "https://cache.numtide.com"
      "https://nvf.cachix.org"
      "https://hugo-berendi.cachix.org"
    ];

    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "smos.cachix.org-1:YOs/tLEliRoyhx7PnNw36cw2Zvbw5R0ASZaUlpUv+yM="
      "intray.cachix.org-1:qD7I/NQLia2iy6cbzZvFuvn09iuL4AkTmHvjxrQlccQ="
      "playit-nixos-module.cachix.org-1:22hBXWXBbd/7o1cOnh+p0hpFUVk9lPdRLX3p5YSfRz4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nvf.cachix.org-1:GMQzlEPrdqVlEzWsdk/6NH9TIoRmFVMZLUfBMvNxzlo="
      "hugo-berendi.cachix.org-1:bUxGkcUJGjKZUDcSu6WvzecShvqbpxM4YvkfcbnAm2Q="
    ];
  };
  # }}}

  inputs = {
    # {{{ Nixpkgs instances
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
    # }}}
    # {{{ Additional package repositories
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # }}}

    llm-agents.url = "github:numtide/llm-agents.nix";
    mcp-nixos = {
      url = "github:utensils/mcp-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    skills.url = "git+ssh://forgejo@ssh.git.hugo-berendi.de/hugo-berendi/skills.git";
    skills.flake = false;

    # {{{ Hyprland
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    pyprland = {
      url = "github:hyprland-community/pyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # }}}

    ghostty-pkg = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # {{{ Nix-related tooling
    nixarr = {
      url = "github:rasmus-kirk/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jellarr = {
      url = "github:venkyr77/jellarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # {{{ Storage
    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    # }}}

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    korora.url = "github:adisbladis/korora";
    korora.inputs.nixpkgs.follows = "nixpkgs";

    # }}}
    # {{{ Standalone software
    # {{{ nvf
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # }}}

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
    # }}}
    # {{{ Theming
    stylix.url = "github:nix-community/stylix/release-26.05";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
    rose-pine-hyprcursor.inputs.nixpkgs.follows = "nixpkgs";

    nixcord = {
      url = "github:kaylorben/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # }}}

    playit-nixos-module = {
      url = "github:pedorich-n/playit-nixos-module";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }: let
    # {{{ Nixpkgs instances
    # Hosts get allowUnfree from common/nixpkgs.nix, but that is a nixos module
    # and so reaches neither the flake's own package outputs nor the unstable
    # instance passed around as `upkgs`. flake-parts hands out
    # nixpkgs.legacyPackages, which carries no config at all, so `nix flake
    # check` refused to evaluate packages.chatgpt for being unfree and took CI
    # down with it.
    nixpkgsConfig = {allowUnfree = true;};

    mkPkgs = input: system:
      import input {
        inherit system;
        config = nixpkgsConfig;
      };
    # }}}
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      imports = [];

      flake = {
        overlays = import ./overlays;
        nixosModules = import ./modules/nixos // import ./modules/common;
        homeModules = import ./modules/home-manager // import ./modules/common;

        nixosConfigurations = let
          inherit (inputs.nixpkgs) lib;

          specialArgs = system: {
            inherit inputs;
            outputs = self;
            upkgs = mkPkgs inputs.nixpkgs-unstable system;
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
                  {
                    lib,
                    config,
                    ...
                  }: {
                    imports = lib.lists.optionals (builtins.pathExists ./home/${hostname}.nix) [
                      inputs.home-manager.nixosModules.home-manager
                      {
                        home-manager.users.${config.yomi.pilot.name} = ./home/${hostname}.nix;
                        home-manager.extraSpecialArgs =
                          specialArgs system
                          // {
                            inherit hostname;
                          };
                        home-manager.useUserPackages = true;
                        home-manager.backupFileExtension = "backy";

                        stylix.homeManagerIntegration.followSystem = false;
                        stylix.homeManagerIntegration.autoImport = false;
                        stylix.enableReleaseChecks = false;
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
        pkgs,
        system,
        ...
      }: let
        upkgs = mkPkgs inputs.nixpkgs-unstable system;
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
        # Replaces flake-parts' default of nixpkgs.legacyPackages, which is
        # instantiated without any config, so packages.chatgpt could not be
        # evaluated at all.
        _module.args.pkgs = mkPkgs inputs.nixpkgs system;

        packages = myPkgs // dnsPackages;

        devShells = import ./devshells (
          {
            inherit pkgs;
          }
          // specialArgs
        );

        checks = let
          # tsukuyomi is deliberately absent: that machine runs Windows now, so
          # its configuration is kept dormant rather than built on every push.
          # It is still under nixosConfigurations and can be built by hand.
          hosts = ["amaterasu" "inari" "iso" "wsl"];
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
    };
}
