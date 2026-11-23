{
  pkgs,
  guestSetupScript,
  ...
}: let
  yaml = pkgs.formats.yaml {};
in {
  userData = pkgs.writeText "t3code-vm-user-data.yaml" ("#cloud-config\n"
    + builtins.toJSON {
      users = [
        {
          name = "agent";
          uid = 1000;
          groups = ["sudo"];
          sudo = ["ALL=(ALL) NOPASSWD:ALL"];
          shell = "/bin/bash";
          lock_passwd = true;
          ssh_authorized_keys = ["__MANAGEMENT_PUBLIC_KEY__"];
        }
      ];
      ssh_pwauth = false;
      disable_root = true;
      # Noble provides both the binaries and daemon unit; bootstrap checks the
      # socket and the actual FHS-wrapped T3 executable before reporting readiness.
      package_update = true;
      packages = ["ca-certificates" "curl" "git" "python3" "qemu-guest-agent" "nix-bin" "nix-setup-systemd" "rsync" "libnss3" "libatk-bridge2.0-0t64" "libgbm1" "libasound2t64"];
      write_files =
        [
          {
            path = "/etc/sysctl.d/90-agent-userns.conf";
            permissions = "0644";
            content = "kernel.apparmor_restrict_unprivileged_userns=0\n";
          }
          {
            path = "/etc/ssh/sshd_config.d/t3code-vm.conf";
            permissions = "0644";
            content = "PasswordAuthentication no\nKbdInteractiveAuthentication no\nAuthenticationMethods publickey\n";
          }
        ]
        ++ pkgs.lib.optional (guestSetupScript != null) {
          path = "/usr/local/sbin/t3code-vm-guest-setup";
          permissions = "0755";
          content = builtins.readFile guestSetupScript;
        };
      runcmd =
        [
          ["sysctl" "--system"]
          ["systemctl" "restart" "ssh"]
          # Noble starts the daemon directly during package installation. Stop
          # it before socket activation, which refuses an already running daemon.
          ["systemctl" "stop" "nix-daemon.service"]
          ["systemctl" "enable" "--now" "nix-daemon.socket"]
        ]
        ++ pkgs.lib.optional (guestSetupScript != null) ["bash" "/usr/local/sbin/t3code-vm-guest-setup"];
    });
  networkConfig = yaml.generate "t3code-vm-network.yaml" {
    version = 2;
    ethernets.ens3 = {
      match.macaddress = "02:54:00:e7:00:02";
      set-name = "ens3";
      addresses = ["10.231.0.2/30"];
      routes = [
        {
          to = "0.0.0.0/0";
          via = "10.231.0.1";
        }
      ];
      nameservers.addresses = ["1.1.1.1" "1.0.0.1"];
    };
  };
  metadata = yaml.generate "t3code-vm-meta-data" {
    # A new identity lets cloud-init rerender networking for the initial guest
    # created with the driver-only match, while preserving its existing disk.
    instance-id = "t3code-vm-mac-v1";
    local-hostname = "t3code-vm";
  };
}
