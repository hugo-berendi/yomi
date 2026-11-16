{
  config,
  lib,
  ...
}: {
  # The system half of Nautilus (home/features/desktop/file-manager.nix holds
  # the package, defaults and window rules). These pieces need system services
  # or system-wide environment, so they cannot live in home-manager.
  config = lib.mkIf config.yomi.machine.graphical {
    # Trash, phones over MTP, and smb:// / sftp:// locations in Nautilus all go
    # through gvfs; without it Nautilus can neither trash nor mount anything.
    services.gvfs.enable = true;

    # Space-bar preview in Nautilus.
    services.gnome.sushi.enable = true;

    # "Open in Terminal" in Nautilus' context menu. The module locks the
    # terminal choice in the system dconf database.
    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = "ghostty";
    };

    # Desktop entries with Terminal=true (nvim, yazi, btop) are started through
    # xdg-terminal-exec by GLib; without a list it guesses a terminal or fails.
    xdg.terminal-exec = {
      enable = true;
      settings.default = ["com.mitchellh.ghostty.desktop"];
    };
  };
}
