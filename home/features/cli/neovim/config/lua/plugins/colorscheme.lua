-- colorscheme.lua

-- lavi.nvim
local lavi = {
	"b0o/lavi.nvim",
	name = "lavi",
	lazy = true,
	dependencies = { "rktjmp/lush.nvim" },
}

-- rose-pine
local rose_pine = {
	"rose-pine/neovim",
	name = "rose-pine",
	lazy = true,
	opts = {
		variant = "moon",
		highlight_groups = {
			TelescopeBorder = { fg = "highlight_high", bg = "none" },
			TelescopeNormal = { bg = "none" },
			TelescopePromptNormal = { bg = "base" },
			TelescopeResultsNormal = { fg = "subtle", bg = "none" },
			TelescopeSelection = { fg = "text", bg = "base" },
			TelescopeSelectionCaret = { fg = "rose", bg = "rose" },
		},
		styles = {
			bold = true,
			italic = true,
			transparency = false,
		},
	},
}

local cyberdream = {
	{
		"scottmckendry/cyberdream.nvim",
		name = "cyberdream",
		lazy = false,
		priority = 1000,
		config = function()
			require("cyberdream").setup({
				-- Recommended - see "Configuring" below for more config options
				transparent = true,
				italic_comments = true,
				hide_fillchars = true,
				borderless_telescope = true,
				terminal_colors = true,
			})
			vim.cmd("colorscheme cyberdream") -- set the colorscheme
			local cyberdream = require("lualine.themes.cyberdream")
			require("lualine").setup({
				-- ... other config
				options = {
					theme = "cyberdream",
				},
				-- ... other config
			})
		end,
	},
}

local set_theme = {
	"LazyVim/LazyVim",
	opts = {
		colorscheme = "rose-pine",
	},
}

return { lavi, rose_pine, set_theme }
