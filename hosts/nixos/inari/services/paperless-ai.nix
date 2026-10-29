{config, ...}: {
  # {{{ Reverse proxy
  yomi.nginx.at.paperless-ai.port = config.yomi.ports.paperless-ai;
  # }}}
  # {{{ Secrets
  sops.secrets.paperless_ai_env = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ Service
  virtualisation.oci-containers.containers."paperless-ai" = {
    image = (import ../images.nix).paperless-ai;
    environment = {
      PUID = "1000";
      PGID = "1000";
      PAPERLESS_AI_PORT = toString config.yomi.ports.paperless-ai;
      RAG_SERVICE_URL = "http://127.0.0.1:8000";
      RAG_SERVICE_ENABLED = "true";
    };
    environmentFiles = [config.sops.secrets.paperless_ai_env.path];
    volumes = [
      "paperless-ai_data:/app/data:rw"
    ];
    ports = [
      "${toString config.yomi.ports.paperless-ai}:${toString config.yomi.ports.paperless-ai}/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network=host"
      "--cap-drop=ALL"
      "--security-opt=no-new-privileges=true"
      # These must come after the secret env-file, which can contain the old
      # Ollama settings. llama.cpp exposes an OpenAI-compatible API locally.
      "--env=AI_PROVIDER=custom"
      "--env=CUSTOM_BASE_URL=http://127.0.0.1:${toString config.yomi.ports.llama-cpp-classifier}/v1"
      "--env=CUSTOM_MODEL=qwen3.5-9b"
      "--env=CUSTOM_API_KEY=local"
    ];
  };

  # }}}
}
