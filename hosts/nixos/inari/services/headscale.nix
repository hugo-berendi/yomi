{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.headscale;
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.vpn = {
    subdomain = "vpn";
    inherit port;
    enableAnubis = false;
  };
  # }}}
  # {{{ Service
  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = port;

    settings = {
      server_url = config.yomi.cloudflared.at.vpn.url;

      # {{{ Sqlite backend — recommended by upstream
      database = {
        type = "sqlite";
        sqlite.path = "/var/lib/headscale/db.sqlite";
        sqlite.write_ahead_log = true;
      };
      # }}}

      # {{{ CGNAT prefix allocation (Tailscale-compatible)
      prefixes = {
        v4 = "100.83.0.0/16";
        v6 = "fd7a:115c:a1e0::/48";
        allocation = "sequential";
      };
      # }}}

      # {{{ DERP - reuse the public Tailscale relay map
      derp = {
        urls = ["https://controlplane.tailscale.com/derpmap/default"];
        paths = [];
        auto_update_enabled = true;
        server.enabled = false;
      };
      # }}}

      # {{{ MagicDNS + static records so clients resolve each other by hostname even without an external resolver
      dns = {
        magic_dns = true;
        base_domain = "ts.hugo-berendi.de";
        override_local_dns = true;
        nameservers.global = [
          "100.83.158.40"
          "9.9.9.9"
          "1.1.1.1"
        ];
        extra_records = [
          {
            name = "inari.ts.hugo-berendi.de";
            type = "A";
            value = "100.83.158.40";
          }
          {
            name = "amaterasu.ts.hugo-berendi.de";
            type = "A";
            value = "100.83.0.1";
          }
          {
            name = "tsukuyomi.ts.hugo-berendi.de";
            type = "A";
            value = "100.83.0.2";
          }
        ];
      };
      # }}}

      # {{{ ACLs - editable via `headscale policy set` so we don't need to redeploy to change them
      policy.mode = "database";
      # }}}

      log = {
        level = "info";
        format = "text";
      };

      ephemeral_node_inactivity_timeout = "30m";
    };
  };
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/headscale";
      mode = "u=rwx,g=,o=";
      user = "headscale";
      group = "headscale";
    }
  ];

  systemd.services.headscale.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
    config.yomi.hardening.overrides.network
    {ReadWritePaths = ["/var/lib/headscale"];}
  ];
  # }}}
}
