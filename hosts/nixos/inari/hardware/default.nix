{inputs, ...}: {
  imports = with inputs.nixos-hardware.nixosModules; [
    # common-cpu-intel
    # common-gpu-intel
    # common-pc-laptop
    # common-pc-laptop-hdd
    # common-pc-hdd
    ./generated.nix
  ];

  # Do not suspend on lid closing
  services.logind.settings.Login.HandleLidSwitch = "ignore";

  hardware.amdgpu = {
    opencl.enable = true;
    initrd.enable = true;
  };
  hardware.graphics.enable = true;
}
