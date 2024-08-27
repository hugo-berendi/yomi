{inputs, ...}: {
  # {{{ Imports
  imports = with inputs.nixos-hardware.nixosModules; [
    # common-cpu-intel
    # common-gpu-intel
    # common-pc-laptop
    # common-pc-ssd
    framework-13-7040-amd
    ./generated.nix
  ];
  # }}}
  # {{{ Misc
  hardware.enableAllFirmware = true;
  hardware.opengl.enable = true;
  # }}}
  powerManagement.cpuFreqGovernor = "performance";
}
