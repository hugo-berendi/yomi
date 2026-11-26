{
  config,
  lib,
  pkgs,
  ...
}: let
  # Desktop file IDs, checked against share/applications of the built profile.
  nautilusApp = "org.gnome.Nautilus.desktop";
  imvApp = "imv.desktop";
  mpvApp = "mpv.desktop";
  nvimApp = "nvim.desktop";
  fileRollerApp = "org.gnome.FileRoller.desktop";

  defaultsFor = app: types: lib.genAttrs types (_: [app]);
in {
  # {{{ Packages
  # gvfs, sushi, "Open in Terminal" and xdg-terminal-exec are system-side:
  # home/features/desktop/file-manager/system.nix.
  home.packages = with pkgs; [
    nautilus
    file-roller
    ffmpegthumbnailer # video thumbnails in Nautilus
  ];
  # }}}
  # {{{ Default applications
  # Without these, xdg-open (and every "open" button that goes through the
  # portal) picked whatever registered first, or nothing: only PDFs, links and
  # mailto had a default. The lists follow Omarchy's mimetypes.sh, mapped to
  # the viewers already installed here.
  xdg.mimeApps.defaultApplications = lib.mkMerge [
    (defaultsFor nautilusApp ["inode/directory"])
    (defaultsFor imvApp [
      "image/png"
      "image/jpeg"
      "image/gif"
      "image/webp"
      "image/bmp"
      "image/tiff"
      "image/avif"
      "image/heic"
      "image/svg+xml"
    ])
    (defaultsFor mpvApp [
      "video/mp4"
      "video/x-msvideo"
      "video/x-matroska"
      "video/x-flv"
      "video/x-ms-wmv"
      "video/mpeg"
      "video/ogg"
      "video/webm"
      "video/quicktime"
      "video/3gpp"
      "video/3gpp2"
      "application/ogg"
      "audio/mpeg"
      "audio/flac"
      "audio/ogg"
      "audio/opus"
      "audio/wav"
      "audio/x-wav"
      "audio/mp4"
      "audio/aac"
    ])
    (defaultsFor nvimApp [
      "text/plain"
      "text/markdown"
      "text/x-csrc"
      "text/x-chdr"
      "text/x-c++src"
      "text/x-c++hdr"
      "text/x-python"
      "text/x-shellscript"
      "application/x-shellscript"
      "application/json"
      "application/toml"
      "application/x-yaml"
      "text/x-nix"
    ])
    (defaultsFor fileRollerApp [
      "application/zip"
      "application/x-tar"
      "application/x-compressed-tar"
      "application/x-xz-compressed-tar"
      "application/x-zstd-compressed-tar"
      "application/x-bzip2-compressed-tar"
      "application/x-7z-compressed"
      "application/vnd.rar"
      "application/gzip"
    ])
  ];
  # }}}
  # {{{ Look and feel
  # Nautilus is libadwaita: it takes its colours from the gtk-4.0 css the
  # stylix gtk target writes, and dark/light from the color-scheme set in
  # ../default.nix, so no extra theming is needed here.
  dconf.settings = {
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
      show-create-link = true;
      show-delete-permanently = true;
    };
    "org/gtk/gtk4/settings/file-chooser".sort-directories-first = true;
  };

  gtk.gtk3.bookmarks = [
    "file://${config.home.homeDirectory}/projects projects"
    "file://${config.xdg.userDirs.download} downloads"
  ];

  wayland.windowManager.hyprland.settings.window_rule = [
    {
      # Space-bar preview and the portal's open/save dialogs.
      match.class = "^(org\\.gnome\\.NautilusPreviewer|xdg-desktop-portal-gtk)$";
      float = true;
      center = true;
    }
    {
      match.class = "^(org\\.gnome\\.NautilusPreviewer)$";
      opacity = "1.0 override 1.0 override";
      opaque = true;
    }
  ];
  # }}}
  # {{{ Persistence
  # Root is rolled back at boot. Without these, the trash would be emptied on
  # every reboot and Nautilus would forget recent files, tags and per-folder
  # view settings (gvfs-metadata).
  yomi.persistence.at.state.apps.nautilus = {
    directories = [
      "${config.xdg.dataHome}/nautilus"
      "${config.xdg.dataHome}/gvfs-metadata"
    ];
    files = ["${config.xdg.dataHome}/recently-used.xbel"];
  };

  yomi.persistence.at.state.apps.trash = {
    # Deleted files are not worth a backup slot.
    excludeFromLocalBackups = true;
    directories = ["${config.xdg.dataHome}/Trash"];
  };
  # }}}
}
