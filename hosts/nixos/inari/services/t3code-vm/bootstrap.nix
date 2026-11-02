{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.t3codeVm;
  stateDir = "/var/lib/t3code-vm";
  bootstrap = pkgs.runCommand "t3code-vm-bootstrap" {} ''
    mkdir -p "$out/bin" "$out/lib"
    cp ${./bootstrap.py} "$out/lib/bootstrap.py"
    cp ${./guest_setup.py} "$out/lib/guest_setup.py"
    printf '#!${pkgs.runtimeShell}\nexec ${pkgs.python3}/bin/python3 %s/lib/bootstrap.py "$@"\n' "$out" > "$out/bin/t3code-vm-bootstrap"
    chmod +x "$out/bin/t3code-vm-bootstrap"
  '';
  rpc = pkgs.writeText "t3code-vm-rpc.mjs" (builtins.readFile ./rpc.mjs);
in {
  options.yomi.t3codeVm = {
    pilot = lib.mkOption {
      type = lib.types.str;
      default = config.yomi.pilot.name;
      description = "Local pilot account that owns the host T3 link.";
    };
    localUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString config.yomi.ports.t3code}";
      description = "Local T3 server URL used for host-side linking.";
    };
    credentialFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["~/.codex/auth.json" "~/.claude/.credentials.json" "~/.local/share/opencode/auth.json"];
      description = "Allowlisted pilot credential files copied independently when present.";
    };
    providerInstances = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Verified T3 provider-instance settings applied through server.updateSettings.";
    };
    guestHostPublicKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "${stateDir}/guest_host_ed25519.pub";
      description = "Guest host public key consumed by the parent seed provisioner.";
    };
    guestHostKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "${stateDir}/guest_host_ed25519";
      description = "Persistent guest host ed25519 private key consumed by the parent seed provisioner.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.t3code-vm-host-keys = {
      description = "Create persistent T3 VM SSH management keys";
      before = ["t3code-vm-provision.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "t3code-vm";
        Group = "t3code-vm";
        UMask = "0077";
        ExecStart = pkgs.writeShellScript "t3code-vm-host-keys" ''
          set -eu
          if [ ! -s ${stateDir}/ssh_key ]; then
            ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f ${stateDir}/ssh_key
          fi
          if [ ! -s ${cfg.guestHostKeyFile} ] && [ ! -s ${cfg.guestHostPublicKeyFile} ]; then
            ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f ${cfg.guestHostKeyFile}
          fi
          test -s ${cfg.managementKeyFile}
          test -s ${cfg.guestHostKeyFile}
          test -s ${cfg.guestHostPublicKeyFile}
          printf '10.231.0.2 %s\n' "$(cat ${cfg.guestHostPublicKeyFile})" > ${stateDir}/known_hosts
          chmod 600 ${stateDir}/known_hosts
        '';
        ReadWritePaths = [stateDir];
        ProtectSystem = "strict";
        PrivateTmp = true;
      };
    };

    systemd.services.t3code-vm-provision.requires = ["t3code-vm-host-keys.service"];
    systemd.services.t3code-vm-provision.after = ["t3code-vm-host-keys.service"];

    systemd.services.t3code-vm-bootstrap = {
      path = [pkgs.openssh pkgs.nix pkgs.util-linux pkgs.nodejs cfg.toolingPackage];
      description = "Bootstrap and link the T3 Code Ubuntu VM";
      wantedBy = ["multi-user.target"];
      requires = ["t3code-vm.service" "t3code-vm-host-keys.service"];
      after = ["t3code-vm.service" "t3code-vm-host-keys.service"];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.pilot;
        Group = "users";
        LoadCredential = ["ssh_key:${stateDir}/ssh_key" "known_hosts:${stateDir}/known_hosts"];
        ExecStart = lib.escapeShellArgs ([
            "${bootstrap}/bin/t3code-vm-bootstrap"
            "--key"
            "%d/ssh_key"
            "--known-hosts"
            "%d/known_hosts"
            "--package"
            (toString cfg.toolingPackage)
            "--state"
            "/home/${cfg.pilot}/.local/state/t3code-vm/bootstrap.json"
            "--rpc"
            rpc
            "--pilot"
            cfg.pilot
            "--local-url"
            cfg.localUrl
            "--credential-home"
            "/home/${cfg.pilot}"
          ]
          ++ lib.optionals (cfg.providerInstances != {}) [
            "--provider-instances"
            (builtins.toJSON cfg.providerInstances)
          ]
          ++ lib.concatMap (path: ["--credentials" path]) cfg.credentialFiles);
        UMask = "0077";
        ProtectSystem = "strict";
        ReadWritePaths = ["/home/${cfg.pilot}/.t3" "/home/${cfg.pilot}/.local/state/t3code-vm"];
        PrivateTmp = true;
        TimeoutStartSec = "30min";
        Restart = "on-failure";
        RestartSec = 30;
      };
    };
    systemd.tmpfiles.rules = ["d /home/${cfg.pilot}/.local/state/t3code-vm 0700 ${cfg.pilot} users -"];
  };
}
