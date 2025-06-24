{config, ...}: {
  yomi.nginx.at.karakeep.port = config.yomi.ports.karakeep;
  # {{{ General config
  services.karakeep = {
    enable = true;

    extraEnvironment = {
      PORT = toString config.yomi.nginx.at.karakeep.port;
      HOST = "127.0.0.1";

      # Disable signups if desired
      DISABLE_SIGNUPS = "false";
      DISABLE_NEW_RELEASE_CHECK = "false";

      # AI
      OLLAMA_BASE_URL = "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
      OLLAMA_KEEP_ALIVE = "10m";
      INFERENCE_IMAGE_MODEL = "qwen2.5vl:7b";
      INFERENCE_TEXT_MODEL = "qwen3:8b";
      EMBEDDING_TEXT_MODEL = "nomic-embed-text:latest";
      INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";
      INFERENCE_JOB_TIMEOUT_SEC = "120";

      # OCR
      OCR_LANGS = "eng,deu";
    };
    browser = {
      enable = true;
      port = config.yomi.ports.karakeep-browser;
    };
    meilisearch.enable = true;
  };
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/karakeep";
      mode = "u=rwx,g=,o=";
      user = "karakeep";
      group = "karakeep";
    }
  ];
  # }}}
}
