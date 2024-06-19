-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Add Additional Filetypes

vim.filetype.add({
	extension = {
		astro = "astro",
	},
})

-- set options

local set = vim.opt
local g = vim.g
local o = vim.o
local map = vim.keymap

-- global options

set.tabstop = 4
set.softtabstop = 4
set.shiftwidth = 4

set.laststatus = 3 -- Or 3 for global statusline

-- Neovide Config

if g.neovide then
	-- Font
	o.guifont = "Maple Mono NF:h12"

	-- Padding
	g.neovide_padding_top = 6
	g.neovide_padding_bottom = 6
	g.neovide_padding_right = 12
	g.neovide_padding_left = 12

	-- Transparancy
	g.neovide_transparency = 0.6
	g.transparency = 0.0

	-- Theme
	g.neovide_theme = "auto"

	-- Refresh Rate
	g.neovide_refresh_rate = 165

	-- Idle Refresh Rate
	g.neovide_refresh_rate_idle = 5

	-- Disable Fullscreen
	g.neovide_fullscreen = false

	-- Keymaps
	map.set("n", "<D-s>", ":w<CR>") -- Save
	map.set("v", "<D-c>", '"+y') -- Copy
	map.set("n", "<D-v>", '"+P') -- Paste normal mode
	map.set("v", "<D-v>", '"+P') -- Paste visual mode
	map.set("c", "<D-v>", "<C-R>+") -- Paste command mode
	map.set("i", "<D-v>", '<ESC>l"+Pli') -- Paste insert mode
end
