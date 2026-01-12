{
  config,
  lib,
  ...
}: {
  # yomi.cloudflared.at.ai.port = config.yomi.ports.open-webui;
  services.ollama = {
    enable = false;
    host = "0.0.0.0";
    port = config.yomi.ports.ollama;
    user = "ollama";
    models = "/raid5pool/ollama/models";
    loadModels = [
      "deepseek-r1:7b"
      "nomic-embed-text:latest"
      "gemma3:4b"
      "gemma3:12b"
      "qwen2.5-coder:7b"
      "qwen2.5:14b"
    ];
  };

  systemd.services.ollama.serviceConfig = {
    DynamicUser = lib.mkForce false;
    MemoryMax = "0";
    LimitAS = "infinity";
    LimitMEMLOCK = "infinity";
  };

  services.open-webui = {
    enable = false;
    port = config.yomi.ports.open-webui;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      OLLAMA_API_BASE_URL = "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
      WEBUI_AUTH = "True";
      ENABLE_CODE_INTERPRETER = "True";
      CODE_EXECUTION_ENGINE = "jupyter";
      CODE_EXECUTION_JUPYTER_URL = "http://127.0.0.1:${toString config.yomi.ports.jupyter-ai}";
      CODE_EXECUTION_JUPYTER_AUTH = "token";
      CODE_EXECUTION_JUPYTER_AUTH_TOKEN = "123456";
      CODE_INTERPRETER_ENGINE = "jupyter";
      CODE_INTERPRETER_JUPYTER_URL = "http://127.0.0.1:${toString config.yomi.ports.jupyter-ai}";
      CODE_INTERPRETER_JUPYTER_AUTH = "token";
      CODE_INTERPRETER_JUPYTER_AUTH_TOKEN = "123456";
    };
  };

  systemd.services.open-webui.serviceConfig.DynamicUser = lib.mkForce true;

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

  fileSystems."/var/lib/ollama" = {
    device = "/raid5pool/ollama/state";
    options = ["bind"];
  };
}
