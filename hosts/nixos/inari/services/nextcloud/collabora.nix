# Collabora Online, which Nextcloud Office opens documents in. The browser
# loads the editor from its own public hostname (office.*); Collabora calls
# Nextcloud back through a loopback TLS listener on the WOPI port.
{
  config,
  lib,
  pkgs,
  upkgs,
  ...
}: let
  cfg = config.services.nextcloud;
  cloud = config.yomi.web.at.cloud;
  office = config.yomi.web.at.office;
  wopiPort = config.yomi.ports.nextcloud-wopi;
  wopiCallback = "https://${cloud.host}:${toString wopiPort}";
  wopiHosts = pkgs.concatText "coolwsd-hosts" [
    config.environment.etc.hosts.source
    (pkgs.writeText "coolwsd-nextcloud-host" "\n127.0.0.1 ${cloud.host}\n")
  ];
in {
  yomi.ports.collabora = 9980;
  yomi.web.at.office = {
    port = config.yomi.ports.collabora;
    transport = "pangolin";
    authentication = "application";
    pangolin.healthCheck = {
      enable = true;
      path = "/hosting/capabilities";
    };
  };

  # The browser loads the editor frame from the separate public office hostname.
  services.collabora-online = {
    enable = true;
    # Stable incorrectly applies LibreOffice 26.2 EOL metadata to Collabora 25.04.
    package = upkgs.collabora-online;
    port = config.yomi.ports.collabora;
    settings = {
      ssl.enable = false;
      ssl.termination = true;
      net = {
        listen = "loopback";
        post_allow.host = ["::1" "127\\.0\\.0\\.1"];
      };
      storage.wopi = {
        "@allow" = true;
        host = [(lib.escapeRegex cloud.host)];
      };
      server_name = office.host;
    };
  };

  # Upstream sets no sandboxing for coolwsd, and it is public (office.*).
  # It jails documents with unprivileged user and mount namespaces
  # (mount_namespaces = true, upstream's default), not setcap'd helpers, so
  # namespaces stay allowed: no RestrictNamespaces, no PrivateUsers. Its only
  # writable state is StateDirectory /var/lib/cool. Not added, because each
  # can break the kit processes: MemoryDenyWriteExecute (LibreOffice
  # generates code), PrivateDevices and ProtectProc (the jails bind /dev and
  # read /proc of their children). Unverified at runtime until the next switch.
  systemd.services.coolwsd.serviceConfig = {
    # Resolve only Collabora's Nextcloud callbacks to the loopback TLS listener.
    BindReadOnlyPaths = ["${wopiHosts}:/etc/hosts"];
    # The host's nscd would resolve names against its own hosts file.
    InaccessiblePaths = ["/run/nscd"];
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    SystemCallArchitectures = "native";
    RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
  };

  systemd.services.nextcloud-richdocuments-config = {
    description = "Point Nextcloud Office at Collabora";
    after = ["nextcloud-setup.service" "coolwsd.service"];
    requires = ["nextcloud-setup.service"];
    wantedBy = ["multi-user.target"];
    path = [cfg.occ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "nextcloud";
    };
    script = ''
      nextcloud-occ config:app:set richdocuments wopi_url --value='http://[::1]:${toString config.yomi.ports.collabora}'
      nextcloud-occ config:app:set richdocuments public_wopi_url --value=${office.url}
      nextcloud-occ config:app:set richdocuments wopi_callback_url --value=${wopiCallback}
      nextcloud-occ config:app:set richdocuments wopi_allowlist --value="127.0.0.1,::1"
    '';
  };
}
