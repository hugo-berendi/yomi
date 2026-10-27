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
  colors = config.lib.stylix.colors;
  themeCss = pkgs.writeText "nextcloud-theme.css" ''
    :root, body {
      --color-main-background: #${colors.base00};
      --color-main-background-rgb: ${colors.base00-rgb-r}, ${colors.base00-rgb-g}, ${colors.base00-rgb-b};
      --color-main-text: #${colors.base05};
      --color-text-maxcontrast: #${colors.base04};
      --color-background-hover: #${colors.base01};
      --color-background-dark: #${colors.base01};
      --color-background-darker: #${colors.base02};
      --color-border: #${colors.base02};
      --color-border-dark: #${colors.base03};
      --color-primary-element: #${colors.base0D};
      --color-primary-element-text: #${colors.base00};
      --color-primary-element-hover: #${colors.base0C};
    }
  '';

  # Files dropped here in the web UI or the sync client are handed to paperless.
  paperlessInbox = "Paperless";
  consumeDir = config.services.paperless.consumptionDir;

  # {{{ paperless hand-off
  # Moving, not copying: paperless deletes nothing in Nextcloud, and a copy
  # would leave every scan in both places. nextcloud owns the files, so the
  # job runs as nextcloud and writes into the paperless consume directory
  # through the paperless group; the follow-up scan drops the now-missing rows
  # from Nextcloud's file cache.
  paperlessHandoff = pkgs.writeShellApplication {
    name = "nextcloud-to-paperless";
    runtimeInputs = [pkgs.coreutils pkgs.findutils];
    text = ''
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
        [ "$moved" = 1 ] && { ${occ} files:scan --path="$user/files/${paperlessInbox}" --quiet || true; }
      done
      exit 0
    '';
  };
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
      inherit (cfg.package.packages.apps) user_oidc richdocuments theming_customcss;
    };

    settings = {
      overwriteprotocol = "https";
      trusted_proxies = ["127.0.0.1" "::1"];
      trusted_domains = [cloud.host];
      default_phone_region = "DE";
      enforce_theme = "dark";
      maintenance_window_start = 2;
      # Pocket ID is the only way in; local passwords stay for the admin.
      allow_user_to_change_display_name = false;
      user_oidc.auto_provision = true;
    };
    phpOptions."opcache.interned_strings_buffer" = "16";
  };
  # }}}
  # {{{ sso
  # Only nextcloud_* groups are synced, so Pocket ID groups of other services
  # (jellyfin_*) never show up here, and membership of Nextcloud's own admin
  # group is left to nextcloud-admin-sync below: user_oidc cannot rename a
  # claim value, and without the whitelist its sync would strip "admin" from
  # everyone at every login. Login is restricted to members of those groups
  # on this side as well as by the client's allowed groups in Pocket ID.
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
        --scope="openid email profile groups" \
        --unique-uid=0 \
        --mapping-uid=preferred_username \
        --mapping-display-name=name \
        --mapping-email=email \
        --mapping-groups=groups \
        --group-provisioning=1 \
        --group-whitelist-regex='^nextcloud_' \
        --group-restrict-login-to-whitelist=1
      nextcloud-occ config:app:set --value=0 user_oidc allow_multiple_user_backends
    '';
  };
  # nextcloud_admins in Pocket ID means admin here. Runs on a timer because the
  # group sync happens inside the login request; a new admin is promoted within
  # a minute. Only oidc accounts are ever demoted, so the local admin keeps its
  # role.
  systemd.services.nextcloud-admin-sync = {
    description = "Mirror nextcloud_admins into the Nextcloud admin group";
    after = ["nextcloud-setup.service"];
    path = [cfg.occ pkgs.jq pkgs.gnugrep];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
    };
    script = ''
      groups=$(nextcloud-occ group:list --output=json)
      wanted=$(jq -r '.nextcloud_admins // [] | .[]' <<<"$groups")
      current=$(jq -r '.admin // [] | .[]' <<<"$groups")

      for uid in $wanted; do
        grep -qx -- "$uid" <<<"$current" || nextcloud-occ group:adduser admin "$uid"
      done

      for uid in $current; do
        grep -qx -- "$uid" <<<"$wanted" && continue
        backend=$(nextcloud-occ user:info --output=json "$uid" | jq -r .backend)
        [ "$backend" = user_oidc ] && nextcloud-occ group:removeuser admin "$uid"
      done
      exit 0
    '';
  };
  systemd.timers.nextcloud-admin-sync = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
    };
  };
  # }}}
  # {{{ bundled apps
  # Photos ships enabled with Nextcloud. Immich owns the photo library, so the
  # app would only duplicate it (and generate previews nobody looks at).
  systemd.services.nextcloud-disable-apps = {
    description = "Disable bundled Nextcloud apps that Immich replaces";
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
      nextcloud-occ app:disable photos
    '';
  };
  # }}}
  # {{{ theme
  # Mirrors the stylix palette the other services use (immich, forgejo). The
  # theming app takes the accent and login background; the dark surfaces need
  # css variables, delivered by theming_customcss. Dark is enforced so the
  # palette applies to every user instead of following their OS setting.
  systemd.services.nextcloud-theme = {
    description = "Apply the stylix palette to Nextcloud";
    after = ["nextcloud-setup.service"];
    requires = ["nextcloud-setup.service"];
    wantedBy = ["multi-user.target"];
    # Re-run when the palette changes, not only on boot.
    restartTriggers = [themeCss];
    path = [cfg.occ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "nextcloud";
    };
    script = ''
      nextcloud-occ config:app:set theming name --value="Yomi Cloud"
      nextcloud-occ config:app:set theming primary_color --value="#${colors.base0D}"
      nextcloud-occ config:app:set theming background_color --value="#${colors.base00}"
      nextcloud-occ theming:config background backgroundColor
      nextcloud-occ config:app:set theming_customcss customcss --value="$(cat ${themeCss})"
      nextcloud-occ config:app:set theming_customcss cachebuster --value="${builtins.substring 11 8 (builtins.baseNameOf themeCss)}"
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
      ExecStart = lib.getExe paperlessHandoff;
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
  # The module only creates config/ and data/ under datadir. A datadir left
  # behind by ocis (owned by its deleted uid) makes tmpfiles refuse to touch
  # them as an "unsafe path transition", so own the directory itself.
  systemd.tmpfiles.settings."10-nextcloud-datadir".${cfg.datadir}.d = {
    mode = "0750";
    user = "nextcloud";
    group = "nextcloud";
  };
  # }}}
  # {{{ storage
  yomi.persistence.at.state.apps.nextcloud.directories = [
    {
      directory = cfg.home;
      user = "nextcloud";
      group = "nextcloud";
    }
  ];
  # }}}
}
