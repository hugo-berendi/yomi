{
	programs.nixvim.plugins.oil = {
		enable = true;
		settings = {
			columns = ["icon"];
			view_options = {
				show_hidden = true;
			};
			float = {
				padding = 2;
				max_width = 90;
				max_height = 0;
				border = "rounded";
				win_options = {
					winblend = 0;
				};
			};
			preview = {
				max_width = 0.9;
				min_width = [0.4 40];
				width = null;
				max_height = 0.9;
				min_height = [0.5 5];
				height = null;
				border = "rounded";
				win_options = {
					winblend = 0;
				};
			};
			progress = {
				max_width = 0.9;
				min_width = [0.4 40];
				width = null;
				max_height = [10 0.9];
				min_height = [5 0.1];
				height = null;
				border = "rounded";
				minimized_border = "none";
				win_options = {
					winblend = 0;
				};
			};
			keymaps = {
				"g?" = "actions.show_help";
				"<CR>" = "actions.select";
				"<C-v>" = "actions.select_vsplit";
				"<C-s>" = "actions.select_split";
				"<C-t>" = "actions.select_tab";
				"<C-p>" = "actions.preview";
				"<C-c>" = "actions.close";
				"<C-r>" = "actions.refresh";
				"-" = "actions.parent";
				"_" = "actions.open_cwd";
				"`" = "actions.cd";
				"~" = "actions.tcd";
				"gs" = "actions.change_sort";
				"gx" = "actions.open_external";
				"g." = "actions.toggle_hidden";
				"g\\" = "actions.toggle_trash";
			};
			use_default_keymaps = false;
		};
	};

	programs.nixvim.keymaps = [
		{
			mode = "n";
			key = "-";
			action = "<cmd>Oil<cr>";
			options = {desc = "Open parent directory";};
		}
		{
			mode = "n";
			key = "<leader>-";
			action = "<cmd>Oil --float<cr>";
			options = {desc = "Open parent directory (float)";};
		}
	];
}
