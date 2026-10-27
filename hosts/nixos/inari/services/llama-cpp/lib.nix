# One llama-server instance: its system user, a unit that fetches a pinned
# model before starting, the state directory and the sandbox they share.
# The two instances differ in the model, the arguments and the resource
# limits, which is all this takes.
{
  lib,
  pkgs,
}: {
  name,
  description,
  model,
  package,
  args,
  # Resource limits and scheduling weights, merged into serviceConfig.
  limits,
  # Sandbox settings that differ per instance, merged over the shared ones.
  sandbox ? {},
}: let
  stateDir = "/var/lib/${name}";
  modelDir = "${stateDir}/models";
  modelPath = "${modelDir}/${model.file}";
  # Pinned to a repository revision and checked against its LFS hash, so a
  # re-upload under the same name cannot silently swap the weights.
  modelUrl = "https://huggingface.co/${model.repo}/resolve/${model.revision}/${model.file}";
in {
  users.users.${name} = {
    isSystemUser = true;
    group = name;
    home = stateDir;
    createHome = true;
  };
  users.groups.${name} = {};

  systemd.services.${name} = {
    inherit description;
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig =
      {
        Type = "simple";
        User = name;
        Group = name;
        WorkingDirectory = stateDir;
        Restart = "always";
        RestartSec = 5;
        TimeoutStartSec = "infinity";

        ExecStartPre = pkgs.writeShellScript "${name}-fetch-model" ''
          set -euo pipefail
          mkdir -p "${modelDir}"
          if [ ! -f "${modelPath}" ]; then
            echo "Downloading ${model.file}..."
            ${lib.getExe pkgs.curl} -fSL --retry 5 --retry-all-errors -C - \
              -o "${modelPath}.tmp" "${modelUrl}"
            echo "${model.sha256}  ${modelPath}.tmp" | ${lib.getExe' pkgs.coreutils "sha256sum"} -c -
            mv "${modelPath}.tmp" "${modelPath}"
            chmod 644 "${modelPath}"
          fi
          # Drop the weights of models this file no longer names.
          find "${modelDir}" -maxdepth 1 -name '*.gguf' ! -name ${lib.escapeShellArg model.file} -delete
        '';

        ExecStart = lib.escapeShellArgs ([
            (lib.getExe' package "llama-server")
            "--model"
            modelPath
          ]
          ++ args);

        # ExecStartPre writes the model into the state directory, which
        # ProtectSystem=strict would otherwise make read-only.
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
        ReadWritePaths = [stateDir];
      }
      // limits
      // sandbox;
  };

  yomi.persistence.at.state.apps.${name}.directories = [
    {
      directory = stateDir;
      user = name;
      group = name;
    }
  ];
}
