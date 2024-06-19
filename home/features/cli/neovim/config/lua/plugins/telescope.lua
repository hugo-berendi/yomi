-- add telescope-fzf-native
return {
	"telescope.nvim",
	dependencies = {
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "make",
		config = function()
			require("telescope").load_extension("fzf")
		end,
	},
	opts = function()
		require("telescope").setup({
			extensions = {
				["do-the-needful"] = {
					winblend = 10,
				},
			},
		})
	end,
}
