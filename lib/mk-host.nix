# Builds one nixosConfiguration: the host directory, plus its home-manager
# profile when home/<hostname>.nix exists.
{
  inputs,
  self,
  mkPkgs,
}: let
  inherit (inputs.nixpkgs) lib;

  specialArgs = system: {
    inherit inputs;
    outputs = self;
    upkgs = mkPkgs inputs.nixpkgs-unstable system;
  };
in
  {
    system ? "x86_64-linux",
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
            imports = lib.lists.optionals (builtins.pathExists ../home/${hostname}.nix) [
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager.users.${config.yomi.pilot.name} = ../home/${hostname}.nix;
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

        ../hosts/nixos/${hostname}
      ];
    }
