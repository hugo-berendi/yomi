{config, ...}: {
  yomi.cloudflared.at.ai.port = config.yomi.ports.open-webui;
  services.ollama = {
    enable = true;
    port = config.yomi.ports.ollama;
    user = "ollama";
    acceleration = "rocm";
    loadModels = [
      "mistral:7b"
      "deepseek-r1:7b"
      "qwen3:14b"
    ];
  };

  services.open-webui = {
    enable = true;
    port = config.yomi.ports.open-webui;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      OLLAMA_API_BASE_URL = "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
      WEBUI_AUTH = "True";
      ENABLE_CODE_INTERPRETER = "True";
      CODE_EXECUTION_ENGINE = "juypter";
      CODE_EXECUTION_JUPYTER_URL = "http://127.0.0.1:${toString config.yomi.ports.jupyter-ai}";
      CODE_EXECUTION_JUPYTER_AUTH = "token";
      CODE_EXECUTION_JUPYTER_AUTH_TOKEN = "123456";
      CODE_INTERPRETER_ENGINE = "juypter";
      CODE_INTERPRETER_JUPYTER_URL = "http://127.0.0.1:${toString config.yomi.ports.jupyter-ai}";
      CODE_INTERPRETER_JUPYTER_AUTH = "token";
      CODE_INTERPRETER_JUPYTER_AUTH_TOKEN = "123456";
    };
  };

  virtualisation.oci-containers.containers."jupyter-ai" = {
    image = "jupyter/minimal-notebook:latest";
    environment = {
      "JUPYTER_ENABLE_LAB" = "yes";
      "JUPYTER_TOKEN" = "123456";
    };
    volumes = [
      "jupyter_data:${config.services.open-webui.stateDir}/jupyter:rw"
    ];
    ports = [
      "${toString config.yomi.ports.jupyter-ai}:8888/tcp"
    ];
    log-driver = "journald";
  };

  environment.persistence."/persist/state".directories = [
    {
      inherit (config.services.ollama) user group;
      directory = config.services.ollama.home;
      mode = "u=rwx,g=,o=";
    }
    {
      directory = config.services.open-webui.stateDir;
      mode = "u=rwx,g=rwx,o=rwx";
    }
  ];
}
