{
	programs.nixvim.plugins.persistence = {
		enable = true;
	};

	programs.nixvim.keymaps = [
		{
			mode = "n";
			key = "<leader>qs";
			action = "<cmd>lua require('persistence').load()<cr>";
			options = {desc = "Restore Session";};
		}
		{
			mode = "n";
			key = "<leader>ql";
			action = "<cmd>lua require('persistence').load({ last = true })<cr>";
			options = {desc = "Restore Last Session";};
		}
		{
			mode = "n";
			key = "<leader>qd";
			action = "<cmd>lua require('persistence').stop()<cr>";
			options = {desc = "Don't Save Current Session";};
		}
	];
}
