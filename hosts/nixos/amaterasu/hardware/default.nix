{inputs, ...}: {
  # {{{ Imports
  imports = with inputs.nixos-hardware.nixosModules; [
    framework-13-7040-amd
    ./generated.nix
  ];
  # }}}
  # {{{ Misc
  hardware.enableAllFirmware = true;
  hardware.graphics.enable = true;
  hardware.amdgpu.initrd.enable = true;
  # }}}
  # No governor is pinned here on purpose. This machine runs amd-pstate-epp,
  # where power-profiles-daemon picks the governor and the energy preference
  # per power source. Forcing "performance" kept the cores at full clock on
  # battery and fought the daemon for control.

  # Closing the lid on battery suspends; on AC or docked it stays awake, which
  # is what the previous blanket "ignore" was there for.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # The Framework's PCIe links stay in their most awake state under the default
  # policy. Every device on this board supports the deeper states.
  boot.kernelParams = ["pcie_aspm.policy=powersupersave"];
}
