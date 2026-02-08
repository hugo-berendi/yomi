{
  lib,
  pkgs,
  config,
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

    immichApiKeyPath =
      if config.sops.secrets ? "IMMICH_API_KEY"
      then config.sops.secrets.IMMICH_API_KEY.path
      else null;

    wl-immich = pkgs.writeShellScriptBin "wl-immich" ''
      set -euo pipefail

      API_KEY_PATH="${lib.optionalString (immichApiKeyPath != null) immichApiKeyPath}"
      IMMICH_URL="https://immich.hugo-berendi.de"
      IPP_URL="https://share.immich.hugo-berendi.de"

      if [ -z "$API_KEY_PATH" ] || [ ! -f "$API_KEY_PATH" ]; then
        ${_ pkgs.libnotify} -u critical "Immich upload failed" "API key not configured"
        exit 1
      fi

      API_KEY=$(cat "$API_KEY_PATH")

      SCREENSHOT_FILE=$(mktemp --suffix=.png)
      trap 'rm -f "$SCREENSHOT_FILE"' EXIT

      ${_ pkgs.grimblast} save area "$SCREENSHOT_FILE"

      if [ ! -s "$SCREENSHOT_FILE" ]; then
        ${_ pkgs.libnotify} -u critical "Immich upload failed" "Screenshot was empty or cancelled"
        exit 1
      fi

      UPLOAD_RESPONSE=$(${_ pkgs.immich-go} -server="$IMMICH_URL" -key="$API_KEY" upload "$SCREENSHOT_FILE" 2>&1)

      ASSET_ID=$(echo "$UPLOAD_RESPONSE" | ${pkgs.gnugrep}/bin/grep -oP 'AssetID:\K[a-f0-9-]+' | head -1)

      if [ -z "$ASSET_ID" ]; then
        ${_ pkgs.libnotify} -u critical "Immich upload failed" "Could not extract asset ID"
        exit 1
      fi

      SHARE_RESPONSE=$(${_ pkgs.curl} -s -X POST "$IMMICH_URL/api/shared-links" \
        -H "x-api-key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"assetIds\": [\"$ASSET_ID\"], \"type\": \"INDIVIDUAL\"}")

      SHARE_KEY=$(echo "$SHARE_RESPONSE" | ${_ pkgs.jq} -r '.key // empty')

      if [ -z "$SHARE_KEY" ]; then
        ${_ pkgs.libnotify} -u critical "Immich upload failed" "Could not create share link"
        exit 1
      fi

      IPP_LINK="$IPP_URL/share/$SHARE_KEY"
      echo -n "$IPP_LINK" | ${wl-copy}

      ${_ pkgs.libnotify} "Screenshot uploaded" "IPP link copied to clipboard"
    '';
  in
    with pkgs; [
      libnotify
      wl-ocr
      wl-qr
      wl-immich
      wl-clipboard
      hyprpicker
      grimblast
      brightnessctl
      pamixer
      wl-screenrec
      immich-go
      curl
      jq
    ];
  # }}}
}
