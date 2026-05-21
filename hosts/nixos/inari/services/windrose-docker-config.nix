{
  config,
  lib,
  ...
}: {
  services.windrose-docker = {
    enable = true;
    serverName = "SuckDuck 67 Looksgay";
    maxPlayerCount = 4;
    inviteCode = "9974f9b2";
  };
}
