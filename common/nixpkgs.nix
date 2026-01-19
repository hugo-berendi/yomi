{outputs, ...}: {
  nixpkgs = {
    # pkgs = lib.mkForce pkgs;
    # Add all overlays defined in the overlays directory
    overlays = builtins.attrValues outputs.overlays;

    config.allowUnfree = true;

    config.permittedInsecurePackages = [
      "electron-25.9.0"
      "nix-2.15.3"
      "dotnet-runtime-6.0.36"
      "dotnet-sdk-wrapped-6.0.428"
      "dotnet-sdk-6.0.428"
      "electron-27.3.11"
      "aspnetcore-runtime-6.0.36"
      "openssl-1.1.1w"
    ];
  };
}
