# Home Manager for the pilot, with ../home as the base every such host
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
    users.${config.yomi.pilot.name}.imports = [../home];
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
