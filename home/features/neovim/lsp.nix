{...}: {
  programs.nvf.settings.vim.lsp = {
    enable = true;
    inlayHints.enable = true;
    formatOnSave = true;

    lspconfig.sources = {
      nixd = ''
        lspconfig.nixd.setup {
          capabilities = capabilities,
          on_attach = on_attach,
          settings = {
            nixd = {
              formatting = { command = { "alejandra" } },
              nixpkgs = { expr = "import <nixpkgs> { }" },
              options = {
                nixos = { expr = "(builtins.getFlake \"/home/hugob/projects/yomi\").nixosConfigurations.amaterasu.options" },
                ["home-manager"] = { expr = "(builtins.getFlake \"/home/hugob/projects/yomi\").homeConfigurations.amaterasu.options" },
              },
            },
          },
        }
      '';
    };

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
}
