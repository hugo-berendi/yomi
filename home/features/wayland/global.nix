# Common wayland stuff
{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./ags
    ./waybar
    ./wlogout.nix
    ./wlsunset.nix
    ./anyrun.nix

    ./sway

    ../desktop
  ];

  home.sessionVariables.NIXOS_OZONES_WL = "1";
  services.swayosd.enable = true;

  home.packages = let
    # {{{ OCR script
    _ = lib.getExe;

    wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
    wl-paste = "${pkgs.wl-clipboard}/bin/wl-paste";

    # TODO: put this in it's own file perhaps?
    # Taken from [here](https://github.com/fufexan/dotfiles/blob/3b0075fa7a5d38de13c8c32140c4b020b6b32761/home/wayland/default.nix#L14)
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
    # }}}
  in
    with pkgs; [
      libnotify # Send notifications
      wl-ocr # Custom ocr script
      wl-qr # Custom qr scanner script
      wl-clipboard # Clipboard manager
      hyprpicker-new # Color picker
      grimblast # Screenshot tool
      brightnessctl # Adjust screen brightness
      pamixer # Adjust audio volume
      xwaylandvideobridge # screen sharing for xwayland apps like discord
    ];
}
