{
	programs.nixvim.plugins.diffview = {
		enable = true;
	};

	programs.nixvim.keymaps = [
		{
			mode = "n";
			key = "<leader>gd";
			action = "<cmd>DiffviewOpen<cr>";
			options = {desc = "Diff View Open";};
		}
		{
			mode = "n";
			key = "<leader>gD";
			action = "<cmd>DiffviewClose<cr>";
			options = {desc = "Diff View Close";};
		}
		{
			mode = "n";
			key = "<leader>gh";
			action = "<cmd>DiffviewFileHistory<cr>";
			options = {desc = "Diff View File History";};
		}
		{
			mode = "n";
			key = "<leader>gH";
			action = "<cmd>DiffviewFileHistory %<cr>";
			options = {desc = "Diff View Current File History";};
		}
	];
}
