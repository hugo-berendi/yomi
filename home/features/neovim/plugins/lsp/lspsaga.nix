{pkgs, ...}: {
	programs.nixvim.plugins.inc-rename = {
		enable = true;
		settings.cmd_name = "IncRename";
	};

	programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
		lspsaga-nvim
	];

	programs.nixvim.extraConfigLua = ''
		require('lspsaga').setup({
			ui = {
				border = 'rounded',
			},
			lightbulb = {
				enable = true,
				sign = true,
				virtual_text = false,
			},
			symbol_in_winbar = {
				enable = true,
			},
			outline = {
				win_position = 'right',
				win_width = 30,
				auto_preview = true,
				detail = true,
				auto_close = true,
				close_after_jump = false,
				keys = {
					toggle_or_jump = '<CR>',
					quit = 'q',
				},
			},
			finder = {
				keys = {
					shuttle = '[w',
					toggle_or_open = '<CR>',
					vsplit = 'v',
					split = 's',
					tabe = 't',
					tabnew = 'r',
					quit = 'q',
					close = '<ESC>',
				},
			},
			definition = {
				width = 0.6,
				height = 0.5,
				keys = {
					edit = '<CR>',
					vsplit = 'v',
					split = 's',
					tabe = 't',
					quit = 'q',
					close = '<ESC>',
				},
			},
			code_action = {
				num_shortcut = true,
				show_server_name = true,
				extend_gitsigns = true,
				keys = {
					quit = 'q',
					exec = '<CR>',
				},
			},
			diagnostic = {
				show_code_action = true,
				jump_num_shortcut = true,
				keys = {
					exec_action = '<CR>',
					quit = 'q',
					toggle_or_jump = '<CR>',
					quit_in_show = 'q',
				},
			},
		})
	'';

	programs.nixvim.keymaps = [
		{
			mode = "n";
			key = "<leader>rn";
			action = ":IncRename ";
			options = {desc = "Incremental Rename";};
		}
		{
			mode = "n";
			key = "gh";
			action = "<cmd>Lspsaga finder<cr>";
			options = {desc = "LSP Finder";};
		}
		{
			mode = "n";
			key = "gp";
			action = "<cmd>Lspsaga peek_definition<cr>";
			options = {desc = "Peek Definition";};
		}
		{
			mode = "n";
			key = "gP";
			action = "<cmd>Lspsaga peek_type_definition<cr>";
			options = {desc = "Peek Type Definition";};
		}
		{
			mode = "n";
			key = "<leader>ca";
			action = "<cmd>Lspsaga code_action<cr>";
			options = {desc = "Code Action";};
		}
		{
			mode = "v";
			key = "<leader>ca";
			action = "<cmd>Lspsaga code_action<cr>";
			options = {desc = "Code Action";};
		}
		{
			mode = "n";
			key = "<leader>o";
			action = "<cmd>Lspsaga outline<cr>";
			options = {desc = "Outline";};
		}
		{
			mode = "n";
			key = "gK";
			action = "<cmd>Lspsaga hover_doc<cr>";
			options = {desc = "Hover Doc";};
		}
		{
			mode = "n";
			key = "<leader>ci";
			action = "<cmd>Lspsaga incoming_calls<cr>";
			options = {desc = "Incoming Calls";};
		}
		{
			mode = "n";
			key = "<leader>co";
			action = "<cmd>Lspsaga outgoing_calls<cr>";
			options = {desc = "Outgoing Calls";};
		}
	];
}
