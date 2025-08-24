{
  config,
  inputs,
  ...
}: {
  imports = [inputs.declarative-jellyfin.nixosModules.default];
  # {{{ reverse proxy
  yomi.cloudflared.at.media.port = config.yomi.ports.jellyfin;
  # }}}
  # {{{ Secrets
  sops.secrets.jellyfin_admin_passwd = {
    sopsFile = ../../secrets.yaml;
    owner = config.users.users.jellyfin.name;
    group = config.users.users.jellyfin.group;
  };
  # }}}
  #{{{ settings
  services.declarative-jellyfin = {
    enable = true;
    system = {
      serverName = "HugoFlix";
      # Use Hardware Acceleration for trickplay image generation
      trickplayOptions = {
        enableHwAcceleration = true;
        enableHwEncoding = true;
      };
      UICulture = "de";
    };
    network.internalHttpPort = config.yomi.cloudflared.at.media.port;
    libraries = {
      Movies = {
        enabled = true;
        contentType = "movies";
        pathInfos = ["/raid5pool/media/movies"];
        typeOptions.Movies = {
          metadataFetchers = [
            "The Open Movie Database"
            "TheMovieDb"
          ];
          imageFetchers = [
            "The Open Movie Database"
            "TheMovieDb"
          ];
        };
      };
      Shows = {
        enabled = true;
        contentType = "tvshows";
        pathInfos = ["/raid5pool/media/tv"];
      };
    };
    users = {
      Admin = {
        mutable = false;
        hashedPasswordFile = config.sops.secrets.jellyfin_admin_passwd.path;
        permissions.isAdministrator = true;
      };
    };
    plugins = [
      {
        name = "intro skipper";
        url = "https://github.com/intro-skipper/intro-skipper/releases/download/10.10/v1.10.10.19/intro-skipper-v1.10.10.19.zip";
        version = "1.10.10.19";
        targetAbi = "10.10.7.0"; # Required as intro-skipper doesn't provide a meta.json file
        sha256 = "sha256:12hby8vkb6q2hn97a596d559mr9cvrda5wiqnhzqs41qg6i8p2fd";
      }
    ];
  };
  # }}}
}
