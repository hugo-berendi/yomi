_: {
  imports = [
    ./pelican.nix
    ./wings.nix
  ];

  users.users."pelican" = {
    isSystemUser = true;
    group = "pelican";
  };
  users.groups."pelican" = {
    members = ["pelican"];
  };
}
