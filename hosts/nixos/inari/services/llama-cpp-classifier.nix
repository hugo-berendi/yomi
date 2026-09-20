{
  config,
  lib,
  pkgs,
  ...
}: let
  modelDir = "/var/lib/llama-cpp-classifier/models";
  modelFile = "qwen2.5-3b-instruct-q4_k_m.gguf";
  modelBaseUrl = "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main";
  modelPath = "${modelDir}/${modelFile}";
  port = config.yomi.ports.llama-cpp-classifier;
in {
  # {{{ Service
  # A second, much smaller llama.cpp than the 14B next door, dedicated to
  # classifying mail for the n8n inbox organizer.
  #
  # The model was chosen by measurement, not by reputation. On this CPU-only,
  # ten-core, already-loaded box, against a twelve-case labelled set of real
  # German and English mail shapes (bank statement, price change, invitation,
  # parcel, check-in, digest, scam, tax demand, receipt, appointment, order,
  # social notification):
  #
  #   Qwen2.5-14B-Instruct Q4_K_M   accurate, but ~40 s for a single mail
  #   Qwen3-1.7B           Q4_K_M   67% correct,  6.7 s avg
  #   Qwen2.5-3B-Instruct  Q4_K_M   92% correct, 11.3 s avg
  #
  # The 1.7B is not merely less accurate, it is wrong in the way that matters:
  # it filed a doctor's appointment reminder as unsolicited bulk at importance
  # 1. The 3B rated the same mail personal at importance 5. Four seconds per
  # mail is not worth buying that back, and at a nightly batch of a few dozen
  # the whole run is minutes either way.
  users.users.llama-cpp-classifier = {
    isSystemUser = true;
    group = "llama-cpp-classifier";
    home = "/var/lib/llama-cpp-classifier";
    createHome = true;
  };
  users.groups.llama-cpp-classifier = {};

  systemd.services.llama-cpp-classifier = {
    description = "llama.cpp inference server for mail classification";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "simple";
      User = "llama-cpp-classifier";
      Group = "llama-cpp-classifier";
      WorkingDirectory = "/var/lib/llama-cpp-classifier";
      Restart = "always";
      RestartSec = 5;
      TimeoutStartSec = "infinity";

      ExecStartPre = pkgs.writeShellScript "llama-cpp-classifier-fetch-model" ''
        set -euo pipefail
        mkdir -p "${modelDir}"
        if [ ! -f "${modelPath}" ]; then
          echo "Downloading ${modelFile}..."
          ${lib.getExe pkgs.curl} -fSL --retry 5 --retry-all-errors -C - \
            -o "${modelPath}.tmp" "${modelBaseUrl}/${modelFile}"
          mv "${modelPath}.tmp" "${modelPath}"
          chmod 644 "${modelPath}"
        fi
      '';

      ExecStart = lib.escapeShellArgs [
        (lib.getExe' pkgs.llama-cpp "llama-server")
        "--model"
        modelPath
        "--host"
        "127.0.0.1"
        "--port"
        (toString port)
        # A mail excerpt plus the bucket list is a few hundred tokens. The
        # classifier truncates the body to 400 characters precisely so this
        # can stay small: context costs resident memory whether used or not.
        "--ctx-size"
        "4096"
        "--threads"
        "4"
      ];

      # Four threads of ten, so a nightly classification run cannot starve the
      # forty-odd services this box actually exists to run. The model is
      # ~2 GB on disk; the cap leaves room for context and the allocator
      # without letting a leak reach the rest of the machine.
      MemoryMax = "6G";
      CPUQuota = "400%";
    };
  };
  # }}}

  # {{{ Persistence
  # The model is two gigabytes fetched over the network: worth keeping across
  # reboots, and it is regenerable, so it belongs beside the other caches
  # rather than in a backup set.
  yomi.persistence.at.state.apps.llama-cpp-classifier.directories = [
    {
      directory = "/var/lib/llama-cpp-classifier";
      user = "llama-cpp-classifier";
      group = "llama-cpp-classifier";
    }
  ];
  # }}}

  # ExecStartPre writes the model into the state directory, which
  # ProtectSystem=strict would otherwise make read-only.
  systemd.services.llama-cpp-classifier.serviceConfig = {
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateMounts = true;
    PrivateTmp = true;
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
    ReadWritePaths = ["/var/lib/llama-cpp-classifier"];
  };
}
