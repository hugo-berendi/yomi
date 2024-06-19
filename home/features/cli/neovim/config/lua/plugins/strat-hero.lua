-- strat-hero.lua

return {
	"willothy/strat-hero.nvim",
	config = true,
	lazy = true,
	cmd = "StratHero",
	keys = {
		{
			"<leader>ä",
			function()
				vim.cmd("StratHero open")
			end,
			desc = "Open or start Stratagem Hero",
		},
	},
}
