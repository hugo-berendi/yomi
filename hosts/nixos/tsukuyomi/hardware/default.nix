{inputs, ...}: {
  imports = with inputs.nixos-hardware.nixosModules; [
    common-cpu-amd
    common-gpu-amd
    common-pc-ssd
    ./generated.nix
  ];
}
