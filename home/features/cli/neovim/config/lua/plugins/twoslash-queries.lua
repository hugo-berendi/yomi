-- twoslash-queries.lua

return {
	"marilari88/twoslash-queries.nvim",
	opts = {

		multi_line = true, -- to print types in multi line mode
		is_enabled = false, -- to keep disabled at startup and enable it on request with the TwoslashQueriesEnable
		highlight = "Type", -- to set up a highlight group for the virtual text
	},
	keys = {
		{
			"<C-k>",
			"<cmd>TwoslashQueriesInspect<CR>",
			desc = "Inspect Two Slash Queries",
		},
	},
}
