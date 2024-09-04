{pkgs, ...}: {
  # Bootloader.
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    grub = {
      devices = ["nodev"];
      efiSupport = true;
      enable = true;
      theme = pkgs.stdenv.mkDerivation {
        pname = "grub-catppuccin";
        version = "1.0";
        src = pkgs.fetchgit {
          url = "https://github.com/catppuccin/grub";
          deepClone = true;
          hash = "sha256-Kvz9yPXyU8O0Hilu/z5j2zZlCJcWeXl9TtMXfwAGJ1k=";
        };
        installPhase = "  cp -r ./src/catppuccin-mocha-grub-theme $out\n";
      };
      extraEntries = ''
        menuentry "Windows" {
          insmod part_gpt
          insmod fat
          insmod search_fs_uuid
          insmod chain
          search --fs-uuid --set=root $FS_UUID
          chainloader /EFI/Microsoft/Boot/bootmgfw.efi
        }
      '';
    };
  };
}
