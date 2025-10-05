{
	imports = [
		# {{{ ai
		./ai/gen.nix
		# }}}
		# {{{ snippets
		./snippets/luasnip.nix
		# }}}
		# {{{ lsp
		./lsp/lsp.nix
		./lsp/lspsaga.nix
		./lsp/conform.nix
		./lsp/trouble.nix
		# }}}
		# {{{ navigation
		./navigation/flash.nix
		# }}}
		# {{{ git
		./git/gitsigns.nix
		# }}}
		# {{{ editor
		./editor/treesitter.nix
		./editor/wakatime.nix
		./editor/presence.nix
		# }}}
		# {{{ cmp
		./cmp/cmp.nix
		./cmp/lspkind.nix
		./cmp/autopairs.nix
		./cmp/cmp-copilot.nix
		./cmp/schemastore.nix
		# }}}
		# {{{ ui
		./ui/dressing.nix
		./ui/lualine.nix
		./ui/rainbow-delimiters.nix
		# }}}
		# {{{ utils
		./utils/snacks.nix
		./utils/obsidian.nix
		./utils/ts-autotag.nix
		./utils/yazi.nix
		./utils/mini.nix
		./utils/persistence.nix
		./utils/spectre.nix
		./utils/smart-splits.nix
		# }}}
		# {{{ filetypes
		./filetypes/markdown.nix
		./filetypes/latex.nix
		# }}}
	];

	programs.nixvim.plugins = {
		todo-comments = {
			enable = true;
		};
		which-key = {
			enable = true;
			settings = {};
		};
		nvim-autopairs = {
			enable = true;
		};
		colorizer = {
			enable = true;
		};
	};
}
