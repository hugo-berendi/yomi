{
  config,
  inputs,
  pkgs,
  ...
}: let
  pkgs-old = import inputs.nixpkgs-old {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };

  pocketIdUrl = config.yomi.cloudflared.at.pocket-id.url;
  jellyfinUrl = config.yomi.cloudflared.at.media.url;
in {
  # {{{ Imports
  imports = [
    inputs.declarative-jellyfin.nixosModules.default
  ];
  # }}}
  # {{{ Reverse proxy
  yomi.cloudflared.at.media.port = config.yomi.ports.jellyfin;
  # }}}
  # {{{ Secrets
  sops.secrets.jellyfin_oidc_secret = {
    sopsFile = ../../secrets.yaml;
    owner = config.services.declarative-jellyfin.user;
    group = config.services.declarative-jellyfin.group;
  };
  # }}}
  # {{{ Service
  services.declarative-jellyfin = {
    enable = true;
    package = pkgs-old.jellyfin;

    dataDir = "/var/lib/jellyfin";
    configDir = "/var/lib/jellyfin/config";
    cacheDir = "/var/cache/jellyfin";
    logDir = "/var/lib/jellyfin/log";

    backups = true;
    backupCount = 5;
    backupDir = "/var/lib/jellyfin/backups";

    system = {
      serverName = "Inari Media Server";

      pluginRepositories = [
        {
          content = {
            Name = "Jellyfin Stable";
            Url = "https://repo.jellyfin.org/files/plugin/manifest.json";
          };
          tag = "RepositoryInfo";
        }
        {
          content = {
            Name = "Jellyfin SSO Plugin";
            Url = "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json";
          };
          tag = "RepositoryInfo";
        }
      ];
    };

    network = {
      internalHttpPort = config.yomi.ports.jellyfin;
    };

    libraries = {
      Movies = {
        enabled = true;
        contentType = "movies";
        pathInfos = ["/raid5pool/media/movies"];
      };

      Shows = {
        enabled = true;
        contentType = "tvshows";
        pathInfos = ["/raid5pool/media/tv"];
      };

      Music = {
        enabled = true;
        contentType = "music";
        pathInfos = ["/raid5pool/media/music"];
      };

      Books = {
        enabled = true;
        contentType = "books";
        pathInfos = ["/raid5pool/media/books"];
      };
    };

    branding = {
      loginDisclaimer = ''
        <form action="${jellyfinUrl}/sso/OID/start/PocketID">
          <button class="raised block emby-button button-submit">
            Sign in with Pocket ID
          </button>
        </form>
      '';

      customCss = ''
        a.raised.emby-button {
          padding: 0.9em 1em;
          color: inherit !important;
        }
        .disclaimerContainer {
          display: block;
        }
      '';
    };
  };
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.declarative-jellyfin.dataDir;
      mode = "u=rwx,g=rx,o=";
      user = config.services.declarative-jellyfin.user;
      group = config.services.declarative-jellyfin.group;
    }
    {
      directory = config.services.declarative-jellyfin.cacheDir;
      mode = "u=rwx,g=rx,o=";
      user = config.services.declarative-jellyfin.user;
      group = config.services.declarative-jellyfin.group;
    }
  ];
  # }}}
}
