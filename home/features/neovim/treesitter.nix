_: {
  programs.nvf.settings.vim = {
    languages = {
      enableTreesitter = true;
      enableFormat = true;
      enableExtraDiagnostics = true;

      nix.enable = true;
      lua.enable = true;
      typescript.enable = true;
      python.enable = true;
      go.enable = true;
      html.enable = true;
      css.enable = true;
      markdown = {
        enable = true;
        extensions.render-markdown-nvim.enable = true;
      };
      tex.enable = true;
      yaml.enable = true;
      terraform.enable = true;
      bash.enable = true;
      csharp.enable = true;
      helm.enable = true;
      astro.enable = true;
      svelte.enable = true;
    };

    treesitter = {
      enable = true;
      fold = false;
      indent.enable = true;
      highlight.enable = true;

      # Pins the enclosing function, attrset or fold section to the top.
      context = {
        enable = true;
        setupOpts.max_lines = 3;
      };
      # Only for its queries: mini.ai and the ]f/[f moves in
      # keymaps/textobjects.nix use them.
      textobjects.enable = true;
    };
  };
}
