-- typescript-tools.lua

return {
	"pmizio/typescript-tools.nvim",
	dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
	opts = function()
		local api = require("typescript-tools.api")
		local function translateDiagnostics(err, result, ctx, config)
			require("ts-error-translator").translate_diagnostics(err, result, ctx, config)
			vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
		end
		require("typescript-tools").setup({
			on_attach = function(client, bufnr)
				require("twoslash-queries").attach(client, bufnr)
				vim.cmd("TwoslashQueriesEnable")

				client.server_capabilities.documentFormattingProvider = false
			end,
			handlers = {
				["textDocument/publishDiagnostics"] = translateDiagnostics,
			},
		})
	end,
}
