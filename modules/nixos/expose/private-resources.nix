# How a yomi.expose.private entry becomes a Pangolin blueprint resource, and
# which combinations of its settings Pangolin accepts.
{lib}: let
  allowed = e: e.users != [] || e.roles != [];
  portString = ports: lib.concatMapStringsSep "," toString ports;
  hasPortRestrictions = e: lib.elem e.mode ["host" "cidr" "ssh"];
  usesDomain = e: lib.elem e.mode ["http" "inference"];
  destinationPort = e:
    if e.destinationPort == null && e.mode == "ssh"
    then 22
    else e.destinationPort;
  tcpPorts = e:
    if e.mode == "ssh" && e.tcpPorts == []
    then [(destinationPort e)]
    else e.tcpPorts;
  privateResource = name: e:
    {
      inherit name;
      inherit (e) mode users roles;
    }
    // lib.optionalAttrs (e.labels != []) {inherit (e) labels;}
    // lib.optionalAttrs (e.machines != []) {inherit (e) machines;}
    // lib.optionalAttrs (e.sites != []) {inherit (e) sites;}
    // lib.optionalAttrs (e.destination != null) {inherit (e) destination;}
    // lib.optionalAttrs (e.destination != null && destinationPort e != null) {
      destination-port = destinationPort e;
    }
    // lib.optionalAttrs (hasPortRestrictions e) {
      tcp-ports = portString (tcpPorts e);
      udp-ports = portString e.udpPorts;
      disable-icmp = !e.allowICMP;
    }
    // lib.optionalAttrs (e.alias != null) {inherit (e) alias;}
    // lib.optionalAttrs (usesDomain e) {
      full-domain = e.fullDomain;
      ssl = e.ssl != false;
    }
    // lib.optionalAttrs (e.mode == "http") {
      scheme =
        if e.scheme == null
        then "http"
        else e.scheme;
    }
    // lib.optionalAttrs (e.mode == "ssh") {
      auth-daemon =
        {inherit (e.authDaemon) mode pam;}
        // lib.optionalAttrs (e.authDaemon.port != null) {inherit (e.authDaemon) port;};
    }
    // lib.optionalAttrs (e.mode == "inference") {
      ai-providers =
        map (p: {
          inherit (p) provider models;
          access-mode = p.accessMode;
          enabled = p.enable;
        })
        e.aiProviders;
      ai-budget =
        map (b: {
          inherit (b) amount unit period enforcement;
          enabled = b.enable;
        })
        e.aiBudgets;
    };
  privateAssertions = name: e: let
    nativeSSH = e.mode == "ssh" && e.authDaemon.mode == "native";
  in [
    {
      assertion = (allowed e || e.machines != []) && !lib.elem "Admin" e.roles;
      message = "Private Pangolin resource ${name} requires explicit users, roles or machines; do not list Admin.";
    }
    {
      assertion =
        (e.destination != null)
        == (!nativeSSH && !lib.elem e.mode ["exit-node" "inference"])
        && (e.alias == null || lib.elem e.mode ["host" "ssh"])
        && (e.fullDomain != null) == usesDomain e
        && (e.mode != "http" || e.destinationPort != null)
        && (e.destinationPort == null || (e.mode == "http" || (e.mode == "ssh" && !nativeSSH)))
        && (e.scheme == null || e.mode == "http")
        && (e.ssl == null || usesDomain e)
        && (hasPortRestrictions e || (e.tcpPorts == [] && e.udpPorts == [] && !e.allowICMP));
      message = "Private Pangolin resource ${name} has a missing or incompatible destination, alias, domain, port or TLS setting.";
    }
    {
      assertion =
        e.mode
        != "ssh"
        || (e.alias
          != null
          && (e.authDaemon.mode != "remote" || e.authDaemon.port != null)
          && (e.authDaemon.mode == "remote" || builtins.length (lib.unique e.sites) <= 1)
          && lib.elem (destinationPort e) (tcpPorts e));
      message = "Private SSH resource ${name} needs an alias and TCP access to its destination port. Remote auth needs its daemon port; site and native auth support one site.";
    }
    {
      assertion =
        (e.mode == "inference" || (e.aiProviders == [] && e.aiBudgets == []))
        && lib.all (p: p.models == [] || p.accessMode == "select") e.aiProviders
        && builtins.length e.aiBudgets == builtins.length (lib.unique (map (b: "${b.unit}/${b.period}") e.aiBudgets));
      message = "Private Pangolin resource ${name}: AI options require inference mode, selected models require select access, and budget units and periods must be unique.";
    }
  ];
in {
  inherit allowed privateResource privateAssertions;
}
