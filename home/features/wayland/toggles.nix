{
  config,
  pkgs,
  ...
}: let
  # SUPER+CTRL+I. Stopping hypridle turns off dimming, locking and suspend on
  # idle alike, which is what a presentation or a long build wants. hypridle is
  # a plain user unit, so it comes back on the next login regardless.
  idle-toggle = pkgs.writeShellApplication {
    name = "idle-toggle";
    runtimeInputs = [pkgs.systemd pkgs.libnotify];
    text = ''
      if systemctl --user is-active --quiet hypridle.service; then
        systemctl --user stop hypridle.service
        notify-send -u low -i system-lock-screen "Idle lock off" "The screen stays on until you toggle it back."
      else
        systemctl --user start hypridle.service
        notify-send -u low -i system-lock-screen "Idle lock on"
      fi
    '';
  };

  # ALT+PRINT. The first press asks for an area and starts recording it, the
  # second stops it. wl-screenrec encodes on the GPU (VA-API), so recording
  # costs little on the Framework's iGPU.
  screenrecord-toggle = pkgs.writeShellApplication {
    name = "screenrecord-toggle";
    runtimeInputs = with pkgs; [wl-screenrec slurp procps libnotify coreutils];
    text = ''
      if pgrep -x wl-screenrec >/dev/null; then
        pkill -INT -x wl-screenrec
        exit 0
      fi

      geometry=$(slurp) || exit 0
      dir="${config.xdg.userDirs.videos}/screenrecordings"
      mkdir -p "$dir"
      file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"

      notify-send -u low -i media-record "Recording" "ALT+PRINT again to stop."
      wl-screenrec -g "$geometry" -f "$file"
      notify-send -u low -i video-x-generic "Recording saved" "$file"
    '';
  };
in {
  home.packages = [idle-toggle screenrecord-toggle];
}
