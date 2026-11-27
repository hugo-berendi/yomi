# A second NetBird exit node that leaves through Mullvad. A separate NetBird
# client ("mullvad") runs inside the `wg` namespace that nixarr's VPN
# confinement builds (media/vpn.nix), so its default route is Mullvad's
# tunnel. Devices choose it, or inari's own exit, in the NetBird app.
#
# The namespace trusts its veth to the host: 192.168.0.0/16 and 172.16.0.0/12
# route back over wg-br, and inari gives wg-br the LAN's ports. NetBird's
# client also prepends accept rules for its interface to other tables'
# input and forward chains (see networking/nftables.nix). So a prerouting
# chain, a hook NetBird leaves alone, lets traffic from the exit's interface
# continue only if it leaves through Mullvad (wg0): nothing on the namespace
# itself, the host or the LAN.
{
  config,
  lib,
  pkgs,
  ...
}: let
  hasSetupKey = import ../lib/has-secret.nix "netbird_mullvad_setup_key";
  client = config.services.netbird.clients.mullvad;
  namespace = "wg";
  tunnel = "${namespace}0";
  # NetBird's overlay; the account uses 100.80.0.0/16 inside it.
  overlay = "100.64.0.0/10";

  guard = pkgs.writeText "netbird-mullvad-guard.nft" ''
    table inet netbird-mullvad-guard
    delete table inet netbird-mullvad-guard
    table inet netbird-mullvad-guard {
      chain prerouting {
        type filter hook prerouting priority -150; policy accept;
        iifname != "${client.interface}" accept
        fib daddr oifname "${tunnel}" accept comment "Exit traffic leaves through Mullvad"
        drop comment "Nothing on the namespace, the host or the LAN"
      }
    }
  '';
  rule = table: spec: ''
    iptables -t ${table} -C ${spec} 2>/dev/null || iptables -t ${table} -A ${spec}
  '';
in {
  # {{{ Secrets
  sops.secrets.netbird_mullvad_setup_key = lib.mkIf hasSetupKey {sopsFile = ../secrets.yaml;};
  warnings = lib.optional (!hasSetupKey) "netbird_mullvad_setup_key is not in inari's secrets.yaml: the Mullvad exit's NetBird client runs but does not join. Create a setup key for the mullvad-exit group in NetBird's dashboard.";
  # }}}
  # {{{ Service
  services.netbird.clients.mullvad = {
    # Its own namespace, so the port does not clash with inari's client.
    port = 51820;
    environment.NB_MANAGEMENT_URL = "https://netbird.${config.yomi.dns.domain}";
    # Root, like inari's own client: routing needs forwarding and NAT.
    hardened = false;
    login = lib.mkIf hasSetupKey {
      enable = true;
      setupKeyFile = config.sops.secrets.netbird_mullvad_setup_key.path;
    };
    openFirewall = false;
    openInternalFirewall = false;
    config = {
      # The namespace's resolv.conf points at Mullvad and is read-only.
      DisableDNS = true;
      DisableClientRoutes = true;
      # See services/netbird.nix: the pre-created config.json would allow
      # NetBird's SSH server.
      ServerSSHAllowed = false;
    };
  };
  systemd.services.${client.service.name} = {
    vpnConfinement = {
      enable = true;
      vpnNamespace = namespace;
    };
    requires = ["netbird-mullvad-exit.service"];
    after = ["netbird-mullvad-exit.service"];
  };

  # Guard first, then forwarding and NAT through Mullvad. Runs again whenever
  # the namespace is rebuilt, since it is bound to wg.service.
  systemd.services.netbird-mullvad-exit = {
    description = "Let the Mullvad NetBird exit forward through Mullvad only";
    vpnConfinement = {
      enable = true;
      vpnNamespace = namespace;
    };
    path = [pkgs.nftables pkgs.iptables pkgs.procps];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      nft -f ${guard}
      ${rule "filter" "FORWARD -i ${client.interface} -o ${tunnel} -j ACCEPT"}
      ${rule "filter" "FORWARD -i ${tunnel} -o ${client.interface} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"}
      ${rule "nat" "POSTROUTING -s ${overlay} -o ${tunnel} -j MASQUERADE"}
      sysctl -qw net.ipv4.ip_forward=1
    '';
  };
  # }}}
  # {{{ State
  yomi.persistence.at.state.apps.netbird-mullvad.directories = [
    {
      directory = "/var/lib/${client.dir.baseName}";
      mode = "0700";
    }
  ];
  # }}}
}
