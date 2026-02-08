{
  config,
  inputs,
  ...
}: let
  jellyfinUrl = config.yomi.cloudflared.at.media.url;
in {
  # {{{ Imports
  imports = [
    inputs.jellarr.nixosModules.default
  ];
  # }}}
  # {{{ Reverse proxy
  yomi.cloudflared.at.media.port = config.yomi.ports.jellyfin;
  # }}}
  # {{{ Secrets
  sops.secrets.jellyfin_oidc_secret = {
    sopsFile = ../../secrets.yaml;
    owner = config.services.jellyfin.user;
    group = config.services.jellyfin.group;
  };

  sops.secrets.jellarr_api_key = {
    sopsFile = ../../secrets.yaml;
  };

  sops.templates.jellarr-env = {
    content = ''
      JELLARR_API_KEY=${config.sops.placeholder.jellarr_api_key}
    '';
    owner = config.services.jellarr.user;
    group = config.services.jellarr.group;
  };
  # }}}
  # {{{ Jellyfin service
  services.jellyfin = {
    enable = true;
    openFirewall = false;
  };
  # }}}
  # {{{ Jellarr service
  services.jellarr = {
    enable = true;
    user = "jellyfin";
    group = "jellyfin";
    environmentFile = config.sops.templates.jellarr-env.path;

    bootstrap = {
      enable = true;
      apiKeyFile = config.sops.secrets.jellarr_api_key.path;
    };

    config = {
      version = 1;
      base_url = "http://localhost:${toString config.yomi.ports.jellyfin}";

      system = {
        pluginRepositories = [
          {
            name = "Jellyfin Stable";
            url = "https://repo.jellyfin.org/files/plugin/manifest.json";
            enabled = true;
          }
          {
            name = "Jellyfin SSO Plugin";
            url = "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json";
            enabled = true;
          }
        ];
      };

      library = {
        virtualFolders = [
          {
            name = "Movies";
            collectionType = "movies";
            libraryOptions.pathInfos = [{path = "/raid5pool/media/movies";}];
          }
          {
            name = "Shows";
            collectionType = "tvshows";
            libraryOptions.pathInfos = [{path = "/raid5pool/media/tv";}];
          }
          {
            name = "Music";
            collectionType = "music";
            libraryOptions.pathInfos = [{path = "/raid5pool/media/music";}];
          }
          {
            name = "Books";
            collectionType = "books";
            libraryOptions.pathInfos = [{path = "/raid5pool/media/books";}];
          }
        ];
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

      startup = {
        completeStartupWizard = true;
      };
    };
  };
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.jellyfin.dataDir;
      mode = "u=rwx,g=rx,o=";
      user = config.services.jellyfin.user;
      group = config.services.jellyfin.group;
    }
    {
      directory = config.services.jellyfin.cacheDir;
      mode = "u=rwx,g=rx,o=";
      user = config.services.jellyfin.user;
      group = config.services.jellyfin.group;
    }
  ];
  # }}}
}
