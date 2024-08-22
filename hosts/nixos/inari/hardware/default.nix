{inputs, ...}: {
  imports = with inputs.nixos-hardware.nixosModules; [
    # common-cpu-intel
    # common-gpu-intel
    # common-pc-laptop
    # common-pc-laptop-hdd
    # common-pc-hdd
    raspberry-pi-3
    ./generated.nix
  ];

  # Do not suspend on lid closing
  services.logind.lidSwitch = "ignore";
}
