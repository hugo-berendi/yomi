{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.iocaine;
  configFormat = pkgs.formats.toml {};
in {
  options.yomi.iocaine = {
    enable = lib.mkEnableOption "iocaine AI crawler trap";

    package = lib.mkPackageOption pkgs "iocaine" {};

    port = lib.mkOption {
      type = lib.types.port;
      default = config.yomi.ports.iocaine;
      description = "Port for iocaine to listen on";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = configFormat.type;
        options = {
          server = {
            bind = lib.mkOption {
              type = lib.types.str;
              default = "127.0.0.1:${toString cfg.port}";
              description = "Address and port for iocaine to bind to";
            };
          };
          sources = {
            words = lib.mkOption {
              type = lib.types.either lib.types.str lib.types.path;
              default = "${pkgs.miscfiles}/share/web2";
              description = "Path to word list for content generation";
            };
            markov = lib.mkOption {
              type = lib.types.listOf (lib.types.either lib.types.str lib.types.path);
              default = [];
              description = "List of paths to markov chain training data";
            };
          };
        };
      };
      default = {};
      description = "Iocaine configuration options";
    };

    userAgents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Amazonbot"
        "anthropic-ai"
        "Applebot-Extended"
        "Bytespider"
        "CCBot"
        "ChatGPT-User"
        "ClaudeBot"
        "cohere-ai"
        "Diffbot"
        "DuckAssistBot"
        "FacebookBot"
        "FriendlyCrawler"
        "Google-Extended"
        "GoogleOther"
        "GPTBot"
        "ImagesiftBot"
        "img2dataset"
        "Meta-ExternalAgent"
        "OAI-SearchBot"
        "omgili"
        "PerplexityBot"
        "PetalBot"
        "Scrapy"
        "Timpibot"
        "VelenPublicWebCrawler"
        "YouBot"
      ];
      description = "User agents to redirect to iocaine poison pages";
    };

    ipRanges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "IP ranges to redirect to iocaine poison pages";
    };

    nginxExtraConfig = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      default = ''
        if ($iocaine_badagent) { rewrite ^ /.well-known/@iocaine$request_uri; }
        if ($iocaine_badrange) { rewrite ^ /.well-known/@iocaine$request_uri; }
      '';
      description = "Nginx extra config to include in virtual hosts for iocaine redirection";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.commonHttpConfig = let
      userAgentsMap = lib.concatMapStringsSep "\n        " (ua: ''"~*${ua}" 1;'') cfg.userAgents;
      ipRangesMap = lib.concatMapStringsSep "\n        " (range: "${range} 1;") cfg.ipRanges;
    in ''
      map $http_user_agent $iocaine_badagent {
        default 0;
        ${userAgentsMap}
      }

      geo $iocaine_badrange {
        default 0;
        ${ipRangesMap}
      }
    '';

    systemd.services.iocaine = let
      configFile = configFormat.generate "iocaine.toml" cfg.settings;
    in {
      description = "Iocaine - AI crawler poison trap";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      restartTriggers = [configFile];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package} --config-file ${configFile}";
        Restart = "on-failure";
        DynamicUser = true;
        StateDirectory = "iocaine";
        WorkingDirectory = "/var/lib/iocaine";
        ProtectSystem = "strict";
        SystemCallArchitectures = "native";
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        DevicePolicy = "closed";
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        LockPersonality = true;
      };
    };
  };
}
