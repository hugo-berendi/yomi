{inputs, ...}: {
  imports = with inputs.nixos-hardware.nixosModules; [
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
