{
  lib,
  pkgs,
  config,
  ...
}: {
  # {{{ Imports
  imports = [
    ./swaync.nix
    ./swayosd.nix
    ./vicinae.nix
    ./waybar
    ./wlogout.nix
    ./wlsunset.nix

    ../desktop
  ];
  # }}}
  # {{{ Session variables
  home.sessionVariables.NIXOS_OZONE_WL = "1";
  # }}}
  # {{{ Packages
  home.packages = let
    immichApiKeyPath =
      if config.sops.secrets ? "IMMICH_API_KEY"
      then config.sops.secrets.IMMICH_API_KEY.path
      else null;

    wl-ocr = pkgs.writeShellApplication {
      name = "wl-ocr";
      runtimeInputs = with pkgs; [grim slurp tesseract5 wl-clipboard libnotify];
      # `|| true`: the plain script carried on after a cancelled selection.
      text = ''
        grim -g "$(slurp)" -t ppm - \
          | tesseract - - \
          | wl-copy || true
        notify-send "Run ocr on area with output \"$(wl-paste)\""
      '';
    };

    wl-qr = pkgs.writeShellApplication {
      name = "wl-qr";
      runtimeInputs = with pkgs; [grim slurp zbar gawk wl-clipboard libnotify];
      text = ''
        grim -g "$(slurp)" -t ppm - \
          | zbarimg --quiet - \
          | awk '{sub(/^QR-Code:/, "", $1); print $1}' \
          | wl-copy || true
        notify-send "Scanned qr code on area with output \"$(wl-paste)\""
      '';
    };

    wl-immich = pkgs.writeShellApplication {
      name = "wl-immich";
      runtimeInputs = with pkgs; [coreutils gnugrep libnotify grimblast immich-go curl jq wl-clipboard];
      text = ''
        API_KEY_PATH="${lib.optionalString (immichApiKeyPath != null) immichApiKeyPath}"
        IMMICH_URL="https://immich.hugo-berendi.de"
        IPP_URL="https://share.immich.hugo-berendi.de"

        if [ -z "$API_KEY_PATH" ] || [ ! -f "$API_KEY_PATH" ]; then
          notify-send -u critical "Immich upload failed" "API key not configured"
          exit 1
        fi

        API_KEY=$(cat "$API_KEY_PATH")

        SCREENSHOT_FILE=$(mktemp --suffix=.png)
        trap 'rm -f "$SCREENSHOT_FILE"' EXIT

        grimblast save area "$SCREENSHOT_FILE"

        if [ ! -s "$SCREENSHOT_FILE" ]; then
          notify-send -u critical "Immich upload failed" "Screenshot was empty or cancelled"
          exit 1
        fi

        UPLOAD_RESPONSE=$(immich-go -server="$IMMICH_URL" -key="$API_KEY" upload "$SCREENSHOT_FILE" 2>&1)

        ASSET_ID=$(echo "$UPLOAD_RESPONSE" | grep -oP 'AssetID:\K[a-f0-9-]+' | head -1)

        if [ -z "$ASSET_ID" ]; then
          notify-send -u critical "Immich upload failed" "Could not extract asset ID"
          exit 1
        fi

        SHARE_RESPONSE=$(curl -s -X POST "$IMMICH_URL/api/shared-links" \
          -H "x-api-key: $API_KEY" \
          -H "Content-Type: application/json" \
          -d "{\"assetIds\": [\"$ASSET_ID\"], \"type\": \"INDIVIDUAL\"}")

        SHARE_KEY=$(echo "$SHARE_RESPONSE" | jq -r '.key // empty')

        if [ -z "$SHARE_KEY" ]; then
          notify-send -u critical "Immich upload failed" "Could not create share link"
          exit 1
        fi

        IPP_LINK="$IPP_URL/share/$SHARE_KEY"
        echo -n "$IPP_LINK" | wl-copy

        notify-send "Screenshot uploaded" "IPP link copied to clipboard"
      '';
    };
  in
    with pkgs; [
      libnotify
      wl-ocr
      wl-qr
      wl-immich
      wl-clipboard
      hyprpicker
      grimblast
      satty
      brightnessctl
      pamixer
      wl-screenrec
      immich-go
      curl
      jq
    ];
  # }}}
}
