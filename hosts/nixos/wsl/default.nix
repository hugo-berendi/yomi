{
  inputs,
  config,
  ...
}: {
  # {{{ Imports
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ../common/base
    ../common/cli
    ../common/nix.nix
    ../common/users/pilot.nix
  ];
  # }}}

  system.stateVersion = "24.05";

  yomi.pilot.name = "hugob";
  yomi.machine.graphical = false;
  yomi.machine.gaming = false;
  yomi.machine.interactible = true;

  # {{{ WSL configuration
  wsl.enable = true;
  wsl.defaultUser = "hugob";
  wsl.startMenuLaunchers = true;

  wsl.wslConf.automount.root = "/mnt";
  wsl.wslConf.interop.appendWindowsPath = true;
  wsl.wslConf.network.generateHosts = false;
  wsl.wslConf.network.generateResolvConf = true;
  # }}}

  # {{{ Machine ids
  networking.hostName = "wsl";
  environment.etc.machine-id.text = "08357db3540c4cd2b76d4bb7f825ec89";
  # }}}

  # {{{ Disable persistence for WSL
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  # }}}
}
