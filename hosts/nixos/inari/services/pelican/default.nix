{...}: {
  imports = [
    ./pelican.nix
    ./wings.nix
  ];

  users.users."pelican" = {
    isSystemUser = true;
    group = "pelican";
    extraGroups = ["wheel"];
  };
  users.groups."pelican" = {
    members = ["pelican"];
  };
}
