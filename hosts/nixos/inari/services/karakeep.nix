{
  config,
  lib,
  upkgs,
  ...
}: {
  yomi.nginx.at.karakeep.port = config.yomi.ports.karakeep;

  # 26.05 ships karakeep 0.32.0 built against nodejs 24, and its bundled
  # better-sqlite3 cannot survive that pairing: every start aborts a few
  # seconds in with
  #
  #   node::RemoveEnvironmentCleanupHook ... Assertion failed: (env) != nullptr
  #   Statement::~Statement() [better_sqlite3.node]
  #
  # Workers had been core-dumping on every start since 2026-09-17 morning;
  # web only stayed up because nothing restarted it. Unstable's 0.33.1 is
  # built against nodejs 22, which is the pairing that works.
  #
  # Drop this once 26.05 carries a karakeep that starts.
  services.karakeep.package = upkgs.karakeep;
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

      # AI tagging and summaries through the classifier llama.cpp, the one
      # local runtime (Ollama is gone). It has a single slot, so bookmarks
      # queue behind the mail sorter instead of competing with it; both run
      # at the lowest CPU weight in the background. The server ignores the
      # key but karakeep refuses to enable the OpenAI client without one.
      OPENAI_BASE_URL = "http://127.0.0.1:${toString config.yomi.ports.llama-cpp-classifier}/v1";
      OPENAI_API_KEY = "unused";
      INFERENCE_TEXT_MODEL = "qwen3.5-9b";
      # No vision projector is loaded, so tagging of image bookmarks will
      # fail; karakeep's default image model does not exist here either.
      INFERENCE_IMAGE_MODEL = "qwen3.5-9b";
      INFERENCE_CONTEXT_LENGTH = "6144";
      # ~30 s a mail on this CPU, more with a queue and a cold model load.
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
  yomi.persistence.at.state.apps.karakeep.directories = [
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
  # Browser is left out: it drives a headless chromium and wants a wider
  # sandbox than the rest.
  systemd.services =
    lib.genAttrs ["karakeep-init" "karakeep-web" "karakeep-workers"]
    (_: {
      serviceConfig = {
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        # Preserve the existing sandbox; upstream spells the same value "yes".
        PrivateTmp = lib.mkForce true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        ReadWritePaths = ["/var/lib/karakeep"];
      };
    });
  # }}}
}
