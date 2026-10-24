{
  config,
  lib,
  ...
}: let
  cfg = config.services.ollama;
in {
  # yomi.cloudflared.at.ai.port = config.yomi.ports.open-webui;
  # Serves qwen3.5:9b to the Proton mail sorter, and nothing else on purpose:
  # the sorter's prompt and cache are tuned to that model, and every extra
  # model is several GB of RAM on a box that already gives the iGPU to
  # llama-cpp's Qwen3.6-35B. CPU only for the same reason; the sorter runs
  # in the background and budgets minutes per message.
  services.ollama = {
    enable = true;
    # Loopback only. The sorter and karakeep are local; nothing else should
    # be able to feed this model text.
    host = "127.0.0.1";
    port = config.yomi.ports.ollama;
    user = "ollama";
    # On the raid rather than the NVMe, which is near its write endurance.
    models = "/raid5pool/ollama/models";
    loadModels = ["qwen3.5:9b"];
    environmentVariables = {
      # One request and one model at a time. The sorter never overlaps
      # itself; this also stops karakeep from loading a second model next to
      # it.
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      # Longer than the sorter's ten-minute tick, so a busy inbox does not
      # reload ~7 GB from the raid every run, and short enough that a quiet
      # evening gives the memory back.
      OLLAMA_KEEP_ALIVE = "15m";
    };
  };

  # The directories predate the static user and belong to nobody, so the
  # model pull could not write. Z fixes ownership recursively at boot.
  systemd.tmpfiles.rules = lib.mkIf cfg.enable [
    "Z /raid5pool/ollama/models 0750 ${cfg.user} ${cfg.user} -"
    "Z /raid5pool/ollama/state 0750 ${cfg.user} ${cfg.user} -"
  ];

  systemd.services.ollama.serviceConfig = lib.mkIf cfg.enable {
    DynamicUser = lib.mkForce false;
    User = lib.mkForce cfg.user;
    # qwen3.5:9b at Q4 is about 6.6 GB plus the 8k context. A hard ceiling
    # keeps a runaway load from taking the host's other services with it.
    MemoryHigh = "10G";
    MemoryMax = "12G";
    # Below the interactive services when the CPU is contended; mail sorting
    # can wait.
    CPUWeight = 20;
    LimitMEMLOCK = "infinity";
  };

  services.open-webui = {
    enable = false;
    port = config.yomi.ports.open-webui;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      OLLAMA_API_BASE_URL = "http://${cfg.host}:${toString cfg.port}";
      WEBUI_AUTH = "True";
    };
  };

  systemd.services.open-webui.serviceConfig.DynamicUser = lib.mkForce true;

  fileSystems."/var/lib/ollama" = lib.mkIf cfg.enable {
    device = "/raid5pool/ollama/state";
    fsType = "none";
    options = ["bind"];
  };
}
