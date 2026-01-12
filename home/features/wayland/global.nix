{
  lib,
  pkgs,
  ...
}: {
  # {{{ Imports
  imports = [
    ./ags
    ./waybar
    ./wlogout.nix
    ./wlsunset.nix
    ./walker.nix

    ../desktop
  ];
  # }}}
  # {{{ Session variables
  home.sessionVariables.NIXOS_OZONES_WL = "1";
  services.swayosd.enable = true;
  # }}}
  # {{{ Packages
  home.packages = let
    _ = lib.getExe;

    wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
    wl-paste = "${pkgs.wl-clipboard}/bin/wl-paste";

    wl-ocr = pkgs.writeShellScriptBin "wl-ocr" ''
      ${_ pkgs.grim} -g "$(${_ pkgs.slurp})" -t ppm - \
        | ${_ pkgs.tesseract5} - - \
        | ${wl-copy}
      ${_ pkgs.libnotify} "Run ocr on area with output \"$(${wl-paste})\""
    '';

    wl-qr = pkgs.writeShellScriptBin "wl-qr" ''
      ${_ pkgs.grim} -g "$(${_ pkgs.slurp})" -t ppm - \
        | ${pkgs.zbar}/bin/zbarimg --quiet - \
        | awk '{sub(/^QR-Code:/, "", $1); print $1}' \
        | ${wl-copy}
      ${
        _ pkgs.libnotify
      } "Scanned qr code on area with output \"$(${wl-paste})\""
    '';
  in
    with pkgs; [
      libnotify
      wl-ocr
      wl-qr
      wl-clipboard
      hyprpicker
      grimblast
      brightnessctl
      pamixer
      wl-screenrec
    ];
  # }}}
}
