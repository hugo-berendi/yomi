{outputs, ...}: {
  nixpkgs = {
    # Add all overlays defined in the overlays directory
    overlays = builtins.attrValues outputs.overlays;

    config.allowUnfree = true;

    config.permittedInsecurePackages = [
      "electron-39.8.10"
      "olm-3.2.16"
      "pnpm-10.29.2"
    ];
  };
}
