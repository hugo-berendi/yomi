{
  config,
  lib,
  pkgs,
  ...
}: let
  modelDir = "/var/lib/llama-cpp/models";
  modelName = "qwen2.5-14b-instruct-q4_k_m.gguf";
  modelUrl = "https://huggingface.co/Qwen/Qwen2.5-14B-Instruct-GGUF/resolve/main/qwen2.5-14b-instruct-q4_k_m.gguf";
  modelPath = "${modelDir}/${modelName}";
  port = config.yomi.ports.llama-cpp;
in {
  # {{{ Service
  users.users.llama-cpp = {
    isSystemUser = true;
    group = "llama-cpp";
    home = "/var/lib/llama-cpp";
    createHome = true;
  };
  users.groups.llama-cpp = {};

  systemd.services.llama-cpp = {
    description = "llama.cpp inference server";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "simple";
      User = "llama-cpp";
      Group = "llama-cpp";
      WorkingDirectory = "/var/lib/llama-cpp";
      Restart = "always";
      RestartSec = 5;

      ExecStartPre = pkgs.writeShellScript "llama-cpp-fetch-model" ''
        set -euo pipefail
        mkdir -p "${modelDir}"
        if [ ! -f "${modelPath}" ]; then
          echo "Downloading ${modelName}..."
          ${lib.getExe pkgs.curl} -fsSL -o "${modelPath}.tmp" "${modelUrl}"
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
        "--ctx-size"
        "32768"
        "--n-predict"
        "-1"
        "--threads"
        "16"
      ];

      # Resource limits suitable for a 58GB server without dGPU
      MemoryMax = "32G";
      CPUQuota = "800%";
    };
  };
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/llama-cpp";
      user = "llama-cpp";
      group = "llama-cpp";
    }
  ];
  # }}}
}
