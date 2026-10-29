{
  config,
  pkgs,
  ...
}: {
  home = {
    packages = [
      pkgs.pandoc
      pkgs.texlive.combined.scheme-full
      pkgs.zotero
    ];

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
