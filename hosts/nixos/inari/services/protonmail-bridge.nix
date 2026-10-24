{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "mail.hugo-berendi.de";
  home = "/var/lib/protonmail-bridge";
  bridge = lib.getExe pkgs.protonmail-bridge;
  ports = config.yomi.ports;

  # The public half of Bridge's self-signed certificate, exported once after
  # the first login and checked in: it is not a secret, and pinning it in git
  # means a regenerated certificate fails closed instead of being trusted on
  # first use. Until it exists the tailnet relay below stays off, so Bridge
  # can be deployed and logged in on its own first.
  bridgeCertificate = ./protonmail-bridge/bridge-cert.pem;
  havePin = builtins.pathExists bridgeCertificate;

  # Bridge keeps its vault key in a keychain. There is no D-Bus session here,
  # so the only helper it can use is pass, and pass needs a GPG key. The key
  # has no passphrase: it sits on the same disk as the vault it unlocks, so a
  # passphrase would have to sit there too and protect nothing.
  keychainSetup = pkgs.writeShellScript "protonmail-bridge-keychain" ''
    set -euo pipefail
    if ! gpg --list-secret-keys protonmail-bridge >/dev/null 2>&1; then
      gpg --batch --pinentry-mode loopback --passphrase "" \
        --quick-gen-key protonmail-bridge default default never
    fi
    if [ ! -f "$HOME/.password-store/.gpg-id" ]; then
      pass init protonmail-bridge
    fi
  '';

  # Login needs a human (password plus 2FA) and the interactive CLI, which
  # cannot run beside the daemon because both take the same lock.
  setup = pkgs.writeShellScriptBin "protonmail-bridge-setup" ''
    set -euo pipefail
    if [ "$(id -u)" -ne 0 ]; then
      echo "run with sudo" >&2
      exit 1
    fi
    systemctl stop protonmail-bridge.service
    trap 'systemctl start protonmail-bridge.service' EXIT
    ${pkgs.util-linux}/bin/runuser -u protonmail-bridge -- \
      env HOME=${home} PATH=${lib.makeBinPath [pkgs.pass pkgs.gnupg]} \
      ${bridge} --cli
  '';

  # Plaintext only between nginx and stunnel, both on loopback. stunnel then
  # speaks STARTTLS to Bridge and accepts nothing but the pinned leaf.
  relay = protocol: accept: connect: {
    accept = "127.0.0.1:${toString accept}";
    connect = "127.0.0.1:${toString connect}";
    inherit protocol;
    CAFile = "${bridgeCertificate}";
    verifyPeer = true;
    # The leaf is self-signed; chain and OCSP checks against public CAs would
    # only ever fail. verifyPeer still requires this exact certificate.
    verifyChain = false;
    OCSPaia = false;
    sslVersionMin = "TLSv1.2";
  };
in {
  # {{{ Service
  # Proton has no IMAP of its own. Bridge decrypts locally and serves IMAP and
  # SMTP on 127.0.0.1 with STARTTLS. It runs here so the Proton sorter can
  # reach the mailbox and other devices get it over the tailnet without a
  # Bridge of their own.
  #
  # One-time, after the first switch (see docs/proton-mail-sorter.md):
  #   sudo protonmail-bridge-setup
  #     login     Proton password + 2FA
  #     info      the Bridge username/password that clients and the sorter use
  # Leave IMAP/SMTP security at STARTTLS: the sorter and stunnel pin that
  # listener's certificate.
  #
  # The nixpkgs module is a user service bound to graphical-session.target,
  # which never starts on this headless box.
  users.users.protonmail-bridge = {
    isSystemUser = true;
    group = "protonmail-bridge";
    inherit home;
  };
  users.groups.protonmail-bridge = {};

  environment.systemPackages = [setup];

  systemd.services.protonmail-bridge = {
    description = "Proton Mail Bridge";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    path = [pkgs.pass pkgs.gnupg];
    environment.HOME = home;

    serviceConfig = {
      User = "protonmail-bridge";
      Group = "protonmail-bridge";
      StateDirectory = "protonmail-bridge";
      StateDirectoryMode = "0700";
      ExecStartPre = keychainSetup;
      ExecStart = "${bridge} --noninteractive";
      Restart = "always";
      RestartSec = 30;

      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      RestrictNamespaces = true;
      LockPersonality = true;
    };
  };
  # }}}
  # {{{ Tailnet access
  # Mail clients on other devices connect with implicit TLS to 993/465 and a
  # real certificate for mail.hugo-berendi.de, which resolves to inari's
  # tailscale address. Listening on every address is safe: the nftables input
  # chain only admits registered ports from br0 and none of these are
  # registered, so in practice only tailscale0 reaches them.
  #
  #   client --TLS--> nginx :993 --plain, loopback--> stunnel :8506
  #          --STARTTLS, pinned--> Bridge :1143
  #
  # nginx cannot do STARTTLS towards a backend, hence stunnel in between.
  services.stunnel = lib.mkIf havePin {
    enable = true;
    clients.proton-imap = relay "imap" ports.proton-imap-relay ports.protonmail-bridge-imap;
    clients.proton-smtp = relay "smtp" ports.proton-smtp-relay ports.protonmail-bridge-smtp;
  };

  security.acme.certs.${domain} = lib.mkIf havePin {
    group = "nginx";
    reloadServices = ["nginx.service"];
  };

  systemd.services.nginx = lib.mkIf havePin {
    wants = ["acme-${domain}.service"];
    after = ["acme-${domain}.service"];
  };

  services.nginx.streamConfig = lib.mkIf havePin (let
    cert = config.security.acme.certs.${domain}.directory;
    tls = port: relayPort: ''
      server {
        listen ${toString port} ssl;
        listen [::]:${toString port} ssl;
        ssl_certificate ${cert}/fullchain.pem;
        ssl_certificate_key ${cert}/key.pem;
        proxy_pass 127.0.0.1:${toString relayPort};
      }
    '';
  in
    tls 993 ports.proton-imap-relay + tls 465 ports.proton-smtp-relay);

  yomi.dns.records = [
    {
      at = "mail";
      type = "CNAME";
      value = "inari.hugo-berendi.de.";
      ttl = 300;
    }
  ];
  # }}}
  # {{{ Sorter
  # The sorter needs the same pin, so it switches on with the relay. It starts
  # as a preview: apply stays false and its n8n workflows ship inactive, so
  # nothing in the mailbox changes until that is flipped deliberately.
  sops.secrets.op_service_account_token = lib.mkIf havePin {
    sopsFile = ./proton-mail-sorter/secrets.yaml;
  };

  yomi.protonMailSorter = lib.mkIf havePin {
    enable = true;
    apply = false;
    bridgePort = ports.protonmail-bridge-imap;
    bridgeCertificateFile = bridgeCertificate;
    serviceAccountTokenFile = config.sops.secrets.op_service_account_token.path;
    # The service account sees only the Automation vault. These are the
    # inari Bridge's credentials, not the Windows Bridge's in Personal.
    # Item IDs, not titles: `op read` rejects the parentheses in
    # "Proton Mail Bridge (inari)", and IDs survive a rename.
    #   fjgnyfe4s4lrreazuvv2j7ouwe  Proton Mail Bridge (inari), Login
    #   jyof6qc6syd5al5rw3uz2uqzvq  Proton Mail Sorter, API credential
    usernameRef = "op://Automation/fjgnyfe4s4lrreazuvv2j7ouwe/username";
    passwordRef = "op://Automation/fjgnyfe4s4lrreazuvv2j7ouwe/password";
    apiTokenRef = "op://Automation/jyof6qc6syd5al5rw3uz2uqzvq/credential";
  };
  # }}}
  # {{{ Storage
  # Not in the app-state backup: the vault only holds the session and the
  # rest is a cache of the mailbox, so losing it costs a login and a resync.
  environment.persistence."/persist/state".directories = [
    {
      directory = home;
      mode = "u=rwx,g=,o=";
      user = "protonmail-bridge";
      group = "protonmail-bridge";
    }
  ];
  # }}}
}
