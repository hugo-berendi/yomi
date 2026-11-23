# Facts about each host that the *other* hosts need: the address /etc/hosts
# maps its name to, and the extra names its sshd answers to (pinned in
# everyone's knownHosts next to keys/ssh_host_ed25519_key.pub).
#
# This is plain data on purpose: reading these from the sibling
# nixosConfigurations instead would make building one host evaluate all of
# them. Each host still declares its own view
# (yomi.dns.records, yomi.ssh.extraHostNames), and assertions in those two
# files fail that host's build when it drifts from the entry here.
let
  domain = "hugo-berendi.de";
in {
  inari = {
    # yomi.inari.lanIPv4 defaults to this.
    ipv4 = "192.168.178.200";
    # Forgejo's git-ssh endpoint, served by inari's own sshd.
    sshAliases = ["ssh.git.${domain}"];
  };

  ebisu = rec {
    ipv4 = "62.83.116.214";
    ipv6 = "2a03:4000:16:16e1:78f7:e3ff:fe9b:63c0";
    # yomi.expose.publicHost, plus the bare addresses.
    sshAliases = ["ebisu.${domain}" ipv4 ipv6];
  };
}
