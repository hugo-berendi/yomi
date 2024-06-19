-- lspconfig.lua

return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			--[[
			"jose-elias-alvarez/typescript.nvim",
			init = function()
				require("lazyvim.util").lsp.on_attach(function(_, buffer)
          -- stylua: ignore
          vim.keymap.set( "n", "<leader>co", "TypescriptOrganizeImports", { buffer = buffer, desc = "Organize Imports" })
					vim.keymap.set("n", "<leader>cR", "TypescriptRenameFile", { desc = "Rename File", buffer = buffer })
				end)
			end,
            ]]
			--
			"dmmulroy/ts-error-translator.nvim",
		},
		---@class PluginLspOpts
		opts = function(_, opts)
			return {
				---@type lspconfig.options
				servers = vim.list_extend(opts.servers or {}, {
					-- tsserver will be automatically installed with mason and loaded with lspconfig
					tsserver = {},
					biome = {},
				}),
				-- you can do any additional lsp server setup here
				-- return true if you don't want this server to be setup with lspconfig
				---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
				setup = {
					-- example to setup with typescript.nvim
					--[[
                tsserver = function(_, opts)
					require("typescript").setup({ server = opts })
					return true
				end,
                ]]
					--
					-- Specify * to use this function as a fallback for any server
					-- ["*"] = function(server, opts) end,
				},
				-- Enable this to enable the builtin LSP inlay hints on Neovim >= 0.10.0
				-- Be aware that you also will need to properly configure your LSP server to
				-- provide the inlay hints.
				inlay_hints = {
					enabled = true,
					exclude = {}, -- filetypes for which you don't want to enable inlay hints
				},
				-- Enable this to enable the builtin LSP code lenses on Neovim >= 0.10.0
				-- Be aware that you also will need to properly configure your LSP server to
				-- provide the code lenses.
				codelens = {
					enabled = false,
				},
				-- options for vim.diagnostic.config()
				---@type vim.diagnostic.Opts
				diagnostics = {
					underline = true,
					update_in_insert = false,
					virtual_text = {
						spacing = 4,
						source = "if_many",
						prefix = "●",
						-- this will set set the prefix to a function that returns the diagnostics icon based on the severity
						-- this only works on a recent 0.10.0 build. Will be set to "●" when not supported
						-- prefix = "icons",
					},
					severity_sort = true,
					signs = {
						text = {
							[vim.diagnostic.severity.ERROR] = LazyVim.config.icons.diagnostics.Error,
							[vim.diagnostic.severity.WARN] = LazyVim.config.icons.diagnostics.Warn,
							[vim.diagnostic.severity.HINT] = LazyVim.config.icons.diagnostics.Hint,
							[vim.diagnostic.severity.INFO] = LazyVim.config.icons.diagnostics.Info,
						},
					},
				},
			}
		end,
	},
	{
		"nvimtools/none-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls").builtins
			opts.sources = vim.list_extend(opts.sources or {}, {
				nls.formatting.biome.with({
					args = {
						"check",
						"--apply-unsafe",
						"--formatter-enabled=true",
						"--organize-imports-enabled=true",
						"--skip-errors",
						"--stdin-file-path",
						"$FILENAME",
					},
				}),
				nls.formatting.clang_format.with({
					filetypes = { "c", "cpp", "java", "cuda", "proto" },
				}),
				nls.formatting.csharpier,
				nls.formatting.alejandra,
			})
		end,
	},
	{ "elkowar/yuck.vim" },
}
