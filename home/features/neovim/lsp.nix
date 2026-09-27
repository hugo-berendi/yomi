{
  config,
  hostname,
  ...
}: let
  flake = ''(builtins.getFlake "${config.home.homeDirectory}/projects/yomi")'';
  host = "${flake}.nixosConfigurations.${hostname}";
in {
  programs.nvf.settings.vim = {
    # {{{ nixd
    # nil (nvf's default) knows no options; nixd evaluates this flake, so
    # yomi.*, NixOS and home-manager options complete and hover with docs.
    languages.nix.lsp.servers = ["nixd"];
    lsp.servers.nixd.settings.nixd = {
      nixpkgs.expr = "import ${flake}.inputs.nixpkgs { }";
      options = {
        nixos.expr = "${host}.options";
        # users.type.getSubOptions misses modules imported per user (nvf,
        # yomi.*); the evaluated user's own option tree has them.
        home-manager.expr = "${host}.options.home-manager.users.valueMeta.attrs.${config.home.username}.configuration.options";
      };
    };
    # }}}

    lsp = {
      enable = true;
      inlayHints.enable = true;
      formatOnSave = true;

      # {{{ Mappings
      # nvf puts everything under <leader>l, which writing.nix uses for LaTeX.
      mappings = {
        goToDefinition = "gd";
        goToDeclaration = "gD";
        goToType = "gy";
        listImplementations = "gI";
        listReferences = "gr";
        hover = "K";
        signatureHelp = "gK";
        renameSymbol = "<leader>cr";
        codeAction = "<leader>ca";
        format = "<leader>cf";
        toggleFormatOnSave = "<leader>uf";
        listDocumentSymbols = "<leader>ss";
        listWorkspaceSymbols = "<leader>sS";
        # Covered by diagnostics.nix (]d, [d, <leader>cd) and illuminate.
        nextDiagnostic = null;
        previousDiagnostic = null;
        openDiagnosticFloat = null;
        documentHighlight = null;
        addWorkspaceFolder = null;
        removeWorkspaceFolder = null;
        listWorkspaceFolders = null;
      };
      # }}}

      trouble = {
        enable = true;
        mappings = {
          workspaceDiagnostics = "<leader>xw";
          documentDiagnostics = "<leader>xd";
          lspReferences = "<leader>xr";
          quickfix = "<leader>xq";
          locList = "<leader>xl";
          symbols = "<leader>xs";
        };
      };
    };
  };
}
