{
  config,
  lib,
  pkgs,
  ...
}: {
  home = {
    packages = [
      pkgs.pandoc
      pkgs.texlive.combined.scheme-full
      pkgs.zotero
    ];

    # Zotero reads user.js on every start and it wins over prefs.js, so the UI
    # stays readable even when the app rewrites its own prefs. The profile dir
    # name is random but fixed once created (see profiles.ini).
    file.".zotero/zotero/977q0pek.default/user.js" = {
      force = true;
      text = lib.concatStrings (lib.mapAttrsToList (name: value: "user_pref(\"${name}\", ${builtins.toJSON value});\n") {
        "extensions.zotero.fontSize" = "1.15";
        "extensions.zotero.uiDensity" = "comfortable";
        "extensions.zotero.note.fontSize" = "16";
        "extensions.zotero.note.fontFamily" = "system-ui, sans-serif";
        "browser.theme.toolbar-theme" = 2;
      });
    };

    file.".latexmkrc".text = ''
      $pdf_mode = 1;
      $bibtex_use = 2;
      $max_repeat = 5;
      $pdflatex = 'pdflatex -synctex=1 -interaction=nonstopmode -file-line-error %O %S';
    '';

    sessionVariables = {
      BIBINPUTS = "${config.home.homeDirectory}/bibliography:";
      TEXINPUTS = ".:${config.home.homeDirectory}/texmf//:";
    };
  };

  xdg.mimeApps.defaultApplications."x-scheme-handler/zotero" = ["zotero.desktop"];

  yomi.persistence.at = {
    data.apps = {
      academic.directories = [
        "bibliography"
        "texmf"
      ];
      zotero.directories = ["Zotero"];
    };
    state.apps.zotero.directories = [
      ".zotero"
      "${config.xdg.configHome}/zotero"
    ];
    cache.apps.zotero.directories = [
      "${config.xdg.cacheHome}/zotero"
    ];
  };
}
