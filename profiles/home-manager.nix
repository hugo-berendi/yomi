# Home Manager for the pilot, with ../features as the base every such host
# shares. Profiles that give a host a user environment import this file;
# a host adds its own settings with
#   home-manager.users.${config.yomi.pilot.name}.imports = [./home.nix];
{
  config,
  inputs,
  outputs,
  upkgs,
  ...
}: {
  imports = [inputs.home-manager.nixosModules.home-manager];

  home-manager = {
    users.${config.yomi.pilot.name}.imports = [../features];
    extraSpecialArgs = {
      inherit inputs outputs upkgs;
      hostname = config.networking.hostName;
    };
    useUserPackages = true;
    backupFileExtension = "backy";
  };

  stylix.homeManagerIntegration.followSystem = false;
  stylix.homeManagerIntegration.autoImport = false;
  stylix.enableReleaseChecks = false;
}
