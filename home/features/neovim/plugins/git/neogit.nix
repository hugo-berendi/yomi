{
	programs.nixvim.plugins.neogit = {
		enable = true;
		settings = {
			kind = "tab";
			commit_editor = {
				kind = "tab";
			};
			commit_select_view = {
				kind = "tab";
			};
			commit_view = {
				kind = "vsplit";
				verify_commit = "vim.fn.executable('gpg') == 1";
			};
			log_view = {
				kind = "tab";
			};
			rebase_editor = {
				kind = "auto";
			};
			reflog_view = {
				kind = "tab";
			};
			merge_editor = {
				kind = "auto";
			};
			tag_editor = {
				kind = "auto";
			};
			preview_buffer = {
				kind = "split";
			};
			popup = {
				kind = "split";
			};
			integrations = {
				telescope = true;
				diffview = true;
			};
		};
	};

	programs.nixvim.keymaps = [
		{
			mode = "n";
			key = "<leader>gg";
			action = "<cmd>Neogit<cr>";
			options = {desc = "Neogit";};
		}
		{
			mode = "n";
			key = "<leader>gc";
			action = "<cmd>Neogit commit<cr>";
			options = {desc = "Git Commit";};
		}
		{
			mode = "n";
			key = "<leader>gp";
			action = "<cmd>Neogit push<cr>";
			options = {desc = "Git Push";};
		}
		{
			mode = "n";
			key = "<leader>gP";
			action = "<cmd>Neogit pull<cr>";
			options = {desc = "Git Pull";};
		}
	];
}
