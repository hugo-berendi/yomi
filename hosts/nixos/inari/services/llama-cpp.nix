{
  config,
  lib,
  pkgs,
  ...
}: let
  modelDir = "/var/lib/llama-cpp/models";
  modelFiles = [
    "qwen2.5-14b-instruct-q4_k_m-00001-of-00003.gguf"
    "qwen2.5-14b-instruct-q4_k_m-00002-of-00003.gguf"
    "qwen2.5-14b-instruct-q4_k_m-00003-of-00003.gguf"
  ];
  modelBaseUrl = "https://huggingface.co/Qwen/Qwen2.5-14B-Instruct-GGUF/resolve/main";
  modelPath = "${modelDir}/${builtins.head modelFiles}";
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
      TimeoutStartSec = "infinity";

      ExecStartPre = pkgs.writeShellScript "llama-cpp-fetch-model" ''
        set -euo pipefail
        mkdir -p "${modelDir}"
        for model in ${lib.escapeShellArgs modelFiles}; do
          if [ ! -f "${modelDir}/$model" ]; then
            echo "Downloading $model..."
            ${lib.getExe pkgs.curl} -fSL --retry 5 --retry-all-errors -C - -o "${modelDir}/$model.tmp" "${modelBaseUrl}/$model"
            mv "${modelDir}/$model.tmp" "${modelDir}/$model"
            chmod 644 "${modelDir}/$model"
          fi
        done
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
  yomi.persistence.at.state.apps.llama-cpp.directories = [
    {
      directory = "/var/lib/llama-cpp";
      user = "llama-cpp";
      group = "llama-cpp";
    }
  ];
  # }}}

  # ExecStartPre downloads models into /var/lib/llama-cpp/models, which
  # ProtectSystem=strict would otherwise make read-only.
  systemd.services.llama-cpp.serviceConfig = {
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
    ReadWritePaths = ["/var/lib/llama-cpp"];
  };
}
