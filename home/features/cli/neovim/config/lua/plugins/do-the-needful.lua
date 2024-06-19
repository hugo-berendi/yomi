-- do-the-needful.lua
return {
	"catgoose/do-the-needful.nvim",
	lazy = true,
	opts = {
		-- Do the needful tasks
		tasks = {},
	},
	keys = {
		{
			"<leader>tp",
			function()
				require("do-the-needful").please()
			end,
			desc = "Open task picker",
		},
		{
			"<leader>ta",
			function()
				require("do-the-needful").actions()
			end,
			desc = "Opens picker to do the needful or edit configs",
		},
		{
			"<leader>tcp",
			function()
				require("do-the-needful").edit_config("project")
			end,
			desc = "Edit project do-the-needful config",
		},
		{
			"<leader>tcg",
			function()
				require("do-the-needful").edit_config("global")
			end,
			desc = "Edit global do-the-needful config",
		},
	},
}
