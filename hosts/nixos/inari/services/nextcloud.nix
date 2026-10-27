{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.nextcloud;
  pocketIdUrl = config.yomi.cloudflared.at.pocket-id.url;
  cloud = config.yomi.cloudflared.at.cloud;
  office = config.yomi.cloudflared.at.office;
  occ = lib.getExe cfg.occ;

  # Files dropped here in the web UI or the sync client are handed to paperless.
  paperlessInbox = "Paperless";
  consumeDir = config.services.paperless.consumptionDir;

  # {{{ paperless hand-off
  # Moving, not copying: paperless deletes nothing in Nextcloud, and a copy
  # would leave every scan in both places. nextcloud owns the files, so the
  # job runs as nextcloud and writes into the paperless consume directory
  # through the paperless group; the follow-up scan drops the now-missing rows
  # from Nextcloud's file cache.
  paperlessHandoff = pkgs.writeShellScript "nextcloud-to-paperless" ''
    shopt -s nullglob
    for inbox in ${cfg.datadir}/data/*/files/${paperlessInbox}; do
      user=$(basename "$(dirname "$(dirname "$inbox")")")
      moved=0
      for f in "$inbox"/*; do
        [ -f "$f" ] || continue
        # Skip files a sync client is still uploading.
        [ -n "$(find "$f" -mmin -1 -print -quit)" ] && continue
        mv -n -- "$f" "${consumeDir}/nextcloud-$user-$(basename "$f")" && moved=1
      done
      [ "$moved" = 1 ] && ${occ} files:scan --path="$user/files/${paperlessInbox}" --quiet
    done
    exit 0
  '';
  # }}}
in {
  # {{{ reverse proxy
  # nginx (the module's own php-fpm vhost) listens on loopback only and
  # cloudflared forwards to it; TLS ends at Cloudflare.
  yomi.cloudflared.at.cloud.port = config.yomi.ports.nextcloud;
  yomi.cloudflared.at.office.port = config.yomi.ports.collabora;

  services.nginx.virtualHosts.${cloud.host} = {
    listen = [
      {
        addr = "127.0.0.1";
        port = config.yomi.ports.nextcloud;
      }
    ];
    # Cloudflare already redirects to HTTPS; nginx must not do so again.
    forceSSL = false;
    enableACME = false;
  };
  # }}}
  # {{{ secrets
  sops.secrets.nextcloud_admin_password = {
    sopsFile = ../secrets.yaml;
    owner = "nextcloud";
  };
  sops.secrets.nextcloud_oidc_client_id = {
    sopsFile = ../secrets.yaml;
    owner = "nextcloud";
  };
  sops.secrets.nextcloud_oidc_client_secret = {
    sopsFile = ../secrets.yaml;
    owner = "nextcloud";
  };
  # }}}
  # {{{ service
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = cloud.host;
    https = true;

    # Config and apps stay in /var/lib/nextcloud, which impermanence persists;
    # the data lives on the RAID, where off-site restic picks it up.
    home = "/var/lib/nextcloud";
    datadir = "/raid5pool/cloud";

    database.createLocally = true;
    configureRedis = true;
    config = {
      dbtype = "pgsql";
      adminuser = "admin";
      adminpassFile = config.sops.secrets.nextcloud_admin_password.path;
    };

    maxUploadSize = "16G";
    autoUpdateApps.enable = true;
    # Apps come from nixpkgs so the store, not the app store, decides versions.
    appstoreEnable = false;
    extraAppsEnable = true;
    extraApps = {
      inherit (cfg.package.packages.apps) user_oidc richdocuments;
    };

    settings = {
      overwriteprotocol = "https";
      trusted_proxies = ["127.0.0.1" "::1"];
      trusted_domains = [cloud.host];
      default_phone_region = "DE";
      maintenance_window_start = 2;
      # Pocket ID is the only way in; local passwords stay for the admin.
      allow_user_to_change_display_name = false;
      user_oidc.auto_provision = true;
    };
    phpOptions."opcache.interned_strings_buffer" = "16";
  };
  # }}}
  # {{{ sso
  # The provider is registered from the secrets on every start so that rotating
  # the Pocket ID client needs no manual occ call. Redirect URI in Pocket ID:
  # ${cloud.url}/apps/user_oidc/code
  systemd.services.nextcloud-oidc-provider = {
    description = "Register Pocket ID as Nextcloud login provider";
    after = ["nextcloud-setup.service"];
    requires = ["nextcloud-setup.service"];
    wantedBy = ["multi-user.target"];
    path = [cfg.occ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "nextcloud";
    };
    script = ''
      nextcloud-occ user_oidc:provider PocketID \
        --clientid="$(cat ${config.sops.secrets.nextcloud_oidc_client_id.path})" \
        --clientsecret="$(cat ${config.sops.secrets.nextcloud_oidc_client_secret.path})" \
        --discoveryuri="${pocketIdUrl}/.well-known/openid-configuration" \
        --scope="openid email profile" \
        --unique-uid=0 \
        --mapping-uid=preferred_username \
        --mapping-display-name=name \
        --mapping-email=email
      nextcloud-occ config:app:set --value=0 user_oidc allow_multiple_user_backends
    '';
  };
  # }}}
  # {{{ collabora
  # Collabora serves plain HTTP on loopback; cloudflared publishes it as its
  # own host because the browser loads the editor frame straight from it.
  services.collabora-online = {
    enable = true;
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
      nextcloud-occ config:app:set richdocuments wopi_url --value=${office.url}
      nextcloud-occ config:app:set richdocuments public_wopi_url --value=${office.url}
      nextcloud-occ config:app:set richdocuments wopi_allowlist --value="127.0.0.1,::1"
    '';
  };
  # }}}
  # {{{ paperless inbox
  users.users.nextcloud.extraGroups = ["paperless"];
  # The consume directory is private to paperless by default; the group needs
  # write access so the hand-off job can drop files in.
  systemd.tmpfiles.settings."10-nextcloud-paperless".${consumeDir}.d = {
    mode = "0770";
    user = config.services.paperless.user;
    group = "paperless";
  };

  systemd.services.nextcloud-to-paperless = {
    description = "Move Nextcloud '${paperlessInbox}' folder contents into paperless";
    after = ["nextcloud-setup.service"];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      ExecStart = paperlessHandoff;
    };
    path = [pkgs.coreutils pkgs.findutils];
  };
  systemd.timers.nextcloud-to-paperless = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "2min";
    };
  };
  # }}}
  # {{{ storage
  environment.persistence."/persist/state".directories = [
    {
      directory = cfg.home;
      user = "nextcloud";
      group = "nextcloud";
    }
  ];
  # }}}
}
