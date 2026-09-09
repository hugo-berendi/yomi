{
  config,
  lib,
  pkgs,
  ...
}: let
  llamaPort = config.yomi.ports.llama-cpp;
  changedetectionPort = config.yomi.ports.changedetection;
  radicalePort = config.yomi.ports.radicale;
in {
  # {{{ Secrets
  sops.secrets.openclaw_telegram_bot_token = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ Service
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    environment = {
      OPENAI_API_KEY = "sk-dummy";
      OPENAI_BASE_URL = "http://127.0.0.1:${toString llamaPort}/v1";
    };

    environmentFiles = [
      config.sops.templates."hermes-env".path
    ];

    settings = {
      model = {
        default = "qwen2.5-14b-instruct";
        base_url = "http://127.0.0.1:${toString llamaPort}/v1";
      };

      toolsets = ["all"];
      max_turns = 100;

      terminal = {
        backend = "local";
        timeout = 180;
      };

      compression = {
        enabled = true;
        threshold = 0.85;
        summary_model = "qwen2.5-14b-instruct";
      };

      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };

      display = {
        compact = false;
        personality = "helpful";
      };

      agent = {
        max_turns = 60;
        verbose = false;
      };

      messaging = {
        telegram = {
          enabled = true;
        };
      };
    };

    extraDependencyGroups = ["messaging"];

    mcpServers = {
      changedetection = {
        command = lib.getExe pkgs.hermes-mcp-changedetection;
        env = {
          CHANGEDETECTION_BASE_URL = "http://127.0.0.1:${toString changedetectionPort}";
        };
      };
      radicale = {
        command = lib.getExe pkgs.hermes-mcp-radicale;
        env = {
          RADICALE_URL = "http://127.0.0.1:${toString radicalePort}/";
          RADICALE_CALENDAR = "hermes";
        };
      };
    };

    extraPackages = with pkgs; [
      curl
      jq
      git
      ripgrep
      fd
      eza
      doggo
    ];

    restart = "always";
    restartSec = 10;
  };

  sops.templates."hermes-env".content = ''
    TELEGRAM_BOT_TOKEN=${config.sops.placeholder.openclaw_telegram_bot_token}
  '';
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.hermes-agent.stateDir;
      user = config.services.hermes-agent.user;
      group = config.services.hermes-agent.group;
    }
  ];
  # }}}
}
