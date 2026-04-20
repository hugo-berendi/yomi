{config, ...}: let
  port = config.yomi.ports.opencode;
  pilot = config.yomi.pilot.name;
in {
  yomi.nginx.at.code.port = port;

  users.users.${pilot}.linger = true;
}
