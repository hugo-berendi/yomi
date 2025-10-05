{pkgs, ...}: {
	programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
		smart-splits-nvim
	];

	programs.nixvim.extraConfigLua = ''
		require('smart-splits').setup({
			ignored_filetypes = { 'nofile', 'quickfix', 'qf', 'prompt' },
			ignored_buftypes = { 'nofile' },
			default_amount = 3,
			at_edge = 'wrap',
			move_cursor_same_row = false,
			cursor_follows_swapped_bufs = false,
			resize_mode = {
				quit_key = '<ESC>',
				resize_keys = { 'h', 'j', 'k', 'l' },
				silent = false,
				hooks = {
					on_enter = nil,
					on_leave = nil,
				},
			},
			ignored_events = {
				'BufEnter',
				'WinEnter',
			},
			multiplexer_integration = nil,
			disable_multiplexer_nav_when_zoomed = true,
		})
	'';

	programs.nixvim.keymaps = [
		{
			mode = "n";
			key = "<C-h>";
			action = "<cmd>lua require('smart-splits').move_cursor_left()<cr>";
			options = {desc = "Move to Left Split";};
		}
		{
			mode = "n";
			key = "<C-j>";
			action = "<cmd>lua require('smart-splits').move_cursor_down()<cr>";
			options = {desc = "Move to Below Split";};
		}
		{
			mode = "n";
			key = "<C-k>";
			action = "<cmd>lua require('smart-splits').move_cursor_up()<cr>";
			options = {desc = "Move to Above Split";};
		}
		{
			mode = "n";
			key = "<C-l>";
			action = "<cmd>lua require('smart-splits').move_cursor_right()<cr>";
			options = {desc = "Move to Right Split";};
		}
		{
			mode = "n";
			key = "<A-h>";
			action = "<cmd>lua require('smart-splits').resize_left()<cr>";
			options = {desc = "Resize Split Left";};
		}
		{
			mode = "n";
			key = "<A-j>";
			action = "<cmd>lua require('smart-splits').resize_down()<cr>";
			options = {desc = "Resize Split Down";};
		}
		{
			mode = "n";
			key = "<A-k>";
			action = "<cmd>lua require('smart-splits').resize_up()<cr>";
			options = {desc = "Resize Split Up";};
		}
		{
			mode = "n";
			key = "<A-l>";
			action = "<cmd>lua require('smart-splits').resize_right()<cr>";
			options = {desc = "Resize Split Right";};
		}
		{
			mode = "n";
			key = "<leader>bh";
			action = "<cmd>lua require('smart-splits').swap_buf_left()<cr>";
			options = {desc = "Swap Buffer Left";};
		}
		{
			mode = "n";
			key = "<leader>bj";
			action = "<cmd>lua require('smart-splits').swap_buf_down()<cr>";
			options = {desc = "Swap Buffer Down";};
		}
		{
			mode = "n";
			key = "<leader>bk";
			action = "<cmd>lua require('smart-splits').swap_buf_up()<cr>";
			options = {desc = "Swap Buffer Up";};
		}
		{
			mode = "n";
			key = "<leader>bl";
			action = "<cmd>lua require('smart-splits').swap_buf_right()<cr>";
			options = {desc = "Swap Buffer Right";};
		}
	];
}
