{
  config,
  lib,
  pkgs,
  ...
}: let
  modelDir = "/var/lib/llama-cpp-classifier/models";
  # Pinned to a repository revision and checked against its LFS hash, so a
  # re-upload under the same name cannot silently swap the weights.
  modelRevision = "3885219b6810b007914f3a7950a8d1b469d598a5";
  modelFile = "Qwen3.5-9B-Q4_K_M.gguf";
  modelSha256 = "03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8";
  modelUrl = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/${modelRevision}/${modelFile}";
  modelPath = "${modelDir}/${modelFile}";
  port = config.yomi.ports.llama-cpp-classifier;
  # nixpkgs builds llama.cpp for the x86-64 baseline (GGML_NATIVE off, as
  # -march=native would make the build depend on the builder). That leaves
  # out every vector instruction: Qwen3.5-9B processed prompts at 9 tokens/s
  # and took ~56 s a mail, where Ollama, which ships CPU variants, took ~31 s.
  # The features are named instead of detected, for inari's Ryzen 7 7735HS
  # (Zen 3+): AVX2, FMA, F16C, BMI2, no AVX-512.
  llamaCpp = pkgs.llama-cpp.overrideAttrs (old: {
    cmakeFlags =
      old.cmakeFlags
      ++ map (feature: lib.cmakeBool "GGML_${feature}" true) ["AVX" "AVX2" "FMA" "F16C" "BMI2"];
  });
in {
  # {{{ Service
  # A second llama.cpp beside the general model next door, for classification
  # work: the Proton mail sorter and the diabetes app's weekly review.
  #
  # Qwen3.5-9B replaced Qwen2.5-3B in October 2026, when the Proton sorter
  # arrived with a prompt and thirteen categories tuned to it. Against twenty
  # labelled synthetic mails it filed 19 correctly at ~31 s each on this CPU
  # (the miss, an expired 2019 deadline filed as Wichtig, is now caught in the
  # sorter's code). It briefly ran under Ollama; one runtime is enough, and
  # Ollama is llama.cpp underneath anyway.
  #
  # The 3B it replaced had been chosen by measurement for the old Migadu
  # organizer: 92% on twelve mails at 11 s, against 67% for Qwen3-1.7B, which
  # filed a doctor's appointment as unsolicited bulk. That trade no longer
  # holds once the work runs in the background with minutes to spare.
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
            -o "${modelPath}.tmp" "${modelUrl}"
          echo "${modelSha256}  ${modelPath}.tmp" | ${lib.getExe' pkgs.coreutils "sha256sum"} -c -
          mv "${modelPath}.tmp" "${modelPath}"
          chmod 644 "${modelPath}"
        fi
        # Drop the weights of models this file no longer names.
        find "${modelDir}" -maxdepth 1 -name '*.gguf' ! -name ${lib.escapeShellArg modelFile} -delete
      '';

      ExecStart = lib.escapeShellArgs [
        (lib.getExe' llamaCpp "llama-server")
        "--model"
        modelPath
        "--alias"
        "qwen3.5-9b"
        "--host"
        "127.0.0.1"
        "--port"
        (toString port)
        # The sorter's system prompt is about 3k tokens and a mail excerpt up
        # to 2k more. One slot keeps the whole context for one request and
        # lets the prompt cache reuse the system prompt between mails.
        "--ctx-size"
        "8192"
        "--parallel"
        "1"
        # Qwen3.5 thinks by default. Classification wants a label, not an
        # essay, and the thinking tokens would cost minutes per mail here.
        "--jinja"
        "--reasoning"
        "off"
        "--threads"
        "8"
      ];

      # CPU only: the iGPU already holds the 35B next door. Eight threads,
      # but the lowest weight, so the services this box exists to run win
      # whenever they want the CPU. ~5.7 GB of weights plus the 8k context.
      MemoryMax = "10G";
      CPUQuota = "800%";
      CPUWeight = 20;
      IOWeight = 20;
      Nice = 10;
    };
  };
  # }}}

  # {{{ Persistence
  # The model is six gigabytes fetched over the network: worth keeping across
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
