{
  config,
  lib,
  ...
}: {
  services.windrose-docker = {
    enable = true;
    serverName = "SuckDuck 67 Looksgay";
    maxPlayerCount = 4;
  };
}
