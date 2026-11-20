# The home fleet's host base: everything in ./base.nix plus the shared
# desktop, user and service collections. ./vps.nix builds on ./base.nix alone.
{
  imports = [
    ./base.nix
    ./profiles/fleet.nix
  ];
}
