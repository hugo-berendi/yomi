{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.t3codeVm;
  stateDir = "/var/lib/t3code-vm";
  # Disposable guest storage stays off the nearly full system pool. Authentication
  # can be seeded again; this disk deliberately has no production backup assignment.
  diskDir = "/raid5pool/t3code-vm";
  userData = import ./guest.nix {
    inherit lib pkgs;
    inherit (cfg) guestSetupScript;
  };
  provision = pkgs.writeScriptBin "t3code-vm-provision" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./provision.py}
  '';
  qemu = "${pkgs.qemu_kvm}/bin/qemu-system-x86_64";
in {
  imports = [./network.nix ./bootstrap.nix];
  options.yomi.t3codeVm = {
    enable = lib.mkEnableOption "the t3code Ubuntu guest VM";

    imageUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cloud-images.ubuntu.com/noble/20260926/noble-server-cloudimg-amd64.img";
      description = "Pinned official Ubuntu cloud image URL.";
    };

    imageSha256 = lib.mkOption {
      type = lib.types.str;
      default = "6a81c37564db9b1ee84e141922625e1d7c5b389b99bb3c572e0243607d5bb4d2";
      description = "SHA-256 checksum for imageUrl.";
    };

    managementKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "${stateDir}/ssh_key.pub";
      description = "Runtime path to the host management public key.";
    };

    toolingPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Optional shared tooling package made available to guest setup.";
    };

    guestSetupScript = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional guest setup script embedded in cloud-init.";
    };

    provisionRequires = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional units required before VM provisioning.";
    };

    provisionAfter = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional units ordered before VM provisioning.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.t3code-vm = {
      isSystemUser = true;
      group = "t3code-vm";
      home = stateDir;
      createHome = true;
    };
    users.groups.t3code-vm = {};

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 t3code-vm t3code-vm -"
      "d ${diskDir} 0700 t3code-vm t3code-vm -"
    ];

    systemd.services.t3code-vm-provision = {
      unitConfig.RequiresMountsFor = [diskDir];
      unitConfig.ConditionPathIsMountPoint = "/raid5pool";
      description = "Provision the t3code VM disk and cloud-init seed";
      wantedBy = ["multi-user.target"];
      requires = ["network-online.target"] ++ cfg.provisionRequires;
      after = ["network-online.target"] ++ cfg.provisionAfter;
      before = ["t3code-vm.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "t3code-vm";
        Group = "t3code-vm";
        WorkingDirectory = stateDir;
        ExecStart = lib.escapeShellArgs [
          "${provision}/bin/t3code-vm-provision"
          "--image-url"
          cfg.imageUrl
          "--image-sha256"
          cfg.imageSha256
          "--image"
          "${stateDir}/ubuntu-base.img"
          "--disk"
          "${diskDir}/root.qcow2"
          "--disk-size"
          "80G"
          "--seed"
          "${stateDir}/seed.iso"
          "--cloud-localds"
          "${pkgs.cloud-utils}/bin/cloud-localds"
          "--qemu-img"
          "${pkgs.qemu}/bin/qemu-img"
          "--user-data"
          userData.userData
          "--network-config"
          userData.networkConfig
          "--metadata"
          userData.metadata
          "--management-key"
          cfg.managementKeyFile
          "--guest-host-key"
          cfg.guestHostKeyFile
          "--guest-host-public-key"
          cfg.guestHostPublicKeyFile
        ];
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [stateDir diskDir];
      };
    };

    systemd.services.t3code-vm = {
      unitConfig.RequiresMountsFor = [diskDir];
      unitConfig.ConditionPathIsMountPoint = "/raid5pool";
      description = "t3code Ubuntu VM";
      requires = ["t3code-vm-provision.service"];
      after = ["t3code-vm-provision.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        User = "t3code-vm";
        Group = "t3code-vm";
        WorkingDirectory = stateDir;
        ExecStart = lib.concatStringsSep " " [
          qemu
          "-enable-kvm"
          "-machine q35,accel=kvm"
          "-cpu host"
          "-smp 4"
          "-m 6144"
          "-nodefaults"
          "-display none"
          "-serial mon:stdio"
          "-qmp unix:${stateDir}/qmp.sock,server=on,wait=off"
          "-drive file=${diskDir}/root.qcow2,if=virtio,format=qcow2,bps=20971520,iops=2000"
          "-drive file=${stateDir}/seed.iso,if=virtio,format=raw,readonly=on"
          "-netdev tap,id=net0,ifname=t3test0,script=no,downscript=no"
          "-device virtio-net-pci,netdev=net0,mac=02:54:00:e7:00:02"
          "-device virtio-rng-pci"
        ];
        Restart = "on-failure";
        ExecStop = "${pkgs.python3}/bin/python3 ${./shutdown.py}";
        RestartSec = 5;
        CPUQuota = "200%";
        CPUWeight = 10;
        DeviceAllow = ["/dev/kvm rw" "/dev/net/tun rw"];
        PrivateDevices = false;
        ProtectSystem = "strict";
        ReadWritePaths = [stateDir diskDir];
        NoNewPrivileges = true;
        KillSignal = "SIGTERM";
        TimeoutStopSec = 30;
      };
    };
  };
}
