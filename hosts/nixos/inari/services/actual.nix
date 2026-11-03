{
  config,
  upkgs,
  ...
}: {
  # {{{ Reverse proxy
  # LAN/VPN only: this is the whole financial history. nginx terminates TLS,
  # which Actual needs anyway (the client uses SharedArrayBuffer, so it only
  # runs in a secure context). The Enable Banking redirect
  # (https://budget.<domain>/enablebanking/auth_callback) is a browser
  # redirect, so it works as long as the browser itself can reach this host.
  yomi.nginx.at.budget = {
    port = config.yomi.ports.actual;
    proxyAddress = "127.0.0.1";
    # nginx defaults to 1M. Actual accepts encrypted sync files up to 50 MB
    # (ACTUAL_UPLOAD_SYNC_ENCRYPTED_FILE_SYNC_SIZE_LIMIT_MB); a budget with a
    # few years of bank-synced transactions passes 1M quickly.
    clientMaxBodySize = "50M";
  };
  # }}}
  # {{{ Service
  services.actual = {
    enable = true;
    # Enable Banking (German PSD2 bank sync) is experimental and arrived in
    # 26.7; 26.8+ fixed its sync window and partial-import failures. Stable
    # 26.05 ships 26.7.0, unstable has the fixes.
    package = upkgs.actual-server;
    settings = {
      hostname = "127.0.0.1";
      port = config.yomi.ports.actual;
      # Only nginx talks to it. The default list trusts every private range,
      # which would let any LAN client spoof X-Forwarded-For past the login
      # rate limiter.
      trustedProxies = ["127.0.0.1/32" "::1/128"];
      loginMethod = "password";
    };
  };
  # }}}
  # {{{ Hardening
  # Upstream already runs it with DynamicUser, an empty capability set,
  # ProtectSystem=strict and a syscall filter. Bank sync only needs outbound
  # HTTPS, which that allows. Nothing local to add.
  # }}}
  # {{{ Storage
  # DynamicUser state lives in /var/lib/private/actual, which
  # hosts/nixos/common/persistence.nix persists as a whole. The restic
  # app-state set takes a consistent copy of account.sqlite.
  # }}}
}
