-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local utils = require("utils")
local buffers = require("utils.buffers")

local map = utils.keymap_factory("n")
local map_with_visual = utils.keymap_factory({ "n", "v" })

local is_default_buffer = function()
	return buffers.is_not_focused_buffer("NvimTree_1", "mind")
end

map("<leader>sf", function()
	if is_default_buffer() then
		local menu = require("custom.srr")
		menu.toggle()
	end
end)
