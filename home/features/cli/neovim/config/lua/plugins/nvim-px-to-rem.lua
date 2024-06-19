-- nvim-px-to-rem.lua
return {
	"jsongerber/nvim-px-to-rem",
	lazy = true,
	opts = {
		root_font_size = 13,
		decimal_count = 4,
		show_virtual_text = true,
		add_cmp_source = true,
		disable_keymaps = false,
		filetypes = {
			"css",
			"scss",
			"sass",
			"astro",
			"html",
			"jsx",
			"tsx",
		},
	},
}
