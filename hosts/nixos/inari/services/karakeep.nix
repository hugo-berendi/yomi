{
  config,
  lib,
  ...
}: {
  yomi.nginx.at.karakeep.port = config.yomi.ports.karakeep;
  # {{{ Secrets
  sops.secrets.karakeep_env = {
    sopsFile = ../secrets.yaml;
    owner = config.users.users.karakeep.name;
    group = config.users.users.karakeep.group;
  };
  # }}}
  # {{{ General config
  services.karakeep = {
    enable = true;

    environmentFile = config.sops.secrets.karakeep_env.path;

    extraEnvironment = {
      PORT = toString config.yomi.nginx.at.karakeep.port;
      HOST = "127.0.0.1";
      NEXTAUTH_URL = config.yomi.nginx.at.karakeep.url;

      # Disable signups if desired
      DISABLE_SIGNUPS = "false";
      DISABLE_NEW_RELEASE_CHECK = "true";

      # AI
      OLLAMA_BASE_URL = "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
      OLLAMA_KEEP_ALIVE = "20m";
      INFERENCE_IMAGE_MODEL = "gemma3:4b";
      INFERENCE_TEXT_MODEL = "gemma3:4b";
      EMBEDDING_TEXT_MODEL = "nomic-embed-text:latest";
      INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";
      INFERENCE_JOB_TIMEOUT_SEC = "600";

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
      user = config.users.users.karakeep.name;
      group = config.users.users.karakeep.group;
    }
  ];

  # There is no karakeep.service. The upstream module ships karakeep-init,
  # karakeep-web, karakeep-workers and karakeep-browser, so hardening
  # systemd.services.karakeep did not harden anything -- it conjured a unit out
  # of the settings alone, which systemd then refused for having no ExecStart
  # ("karakeep.service: Service has no ExecStart=, ExecStop=, or
  # SuccessAction=. Refusing."), while the services that do exist ran unhardened.
  systemd.services = let
    hardened = lib.mkMerge [
      (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
      {ReadWritePaths = ["/var/lib/karakeep"];}
    ];
  in {
    karakeep-init.serviceConfig = hardened;
    karakeep-web.serviceConfig = hardened;
    karakeep-workers.serviceConfig = hardened;
  };
  # }}}
}
