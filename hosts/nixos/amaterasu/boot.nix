{ inputs, pkgs, ... }: {
        # Bootloader.
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      useOSProber = true;
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
      extraConfig = ''
        nowatchdog
        nvme_load=YES
        loglevel=3
        qiet
        splash
      '';
    };
  };
    }
