{...}: {
  programs.nvf.settings.vim = {
    languages = {
      enableTreesitter = true;
      enableFormat = true;
      enableExtraDiagnostics = true;

      nix.enable = true;
      lua.enable = true;
      ts.enable = true;
      python.enable = true;
      go.enable = true;
      html.enable = true;
      css.enable = true;
      markdown.enable = true;
      yaml.enable = true;
      terraform.enable = true;
      bash.enable = true;
      csharp.enable = true;
      helm.enable = true;
    };

    treesitter = {
      enable = true;
      fold = false;
      indent.enable = true;
      highlight.enable = true;
    };
  };
}
