# Builds one nixosConfiguration from hosts/nixos/<hostname>. Home Manager,
# when a host has one, comes from the profile it imports
# (profiles/home-manager.nix), not from here.
{
  inputs,
  self,
  mkPkgs,
}: {
  system ? "x86_64-linux",
  hostname,
}:
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = {
    inherit inputs;
    outputs = self;
    upkgs = mkPkgs inputs.nixpkgs-unstable system;
  };
  modules = [../hosts/nixos/${hostname}];
}
