{config, ...}: let
  port = config.yomi.ports.opencode;
  pilot = config.yomi.pilot.name;
in {
  # opencode runs without a server password: anyone on the LAN can drive an
  # agent session as the pilot.
  yomi.web.at.code = {
    inherit port;
    transport = "nginx";
    authentication = "none";
    homepage = {
      group = "Tooling";
      name = "OpenCode";
      icon = "mdi-console";
      description = "Coding agent workspace";
    };
  };

  users.users.${pilot}.linger = true;
}
