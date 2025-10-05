{...}: {
	programs.nixvim = {
		plugins.inc-rename = {
			enable = true;
			settings.cmd_name = "IncRename";
		};

		keymaps = [
			{
				mode = "n";
				key = "<leader>rn";
				action = ":IncRename ";
				options = {desc = "Incremental Rename";};
			}
			{
				mode = "n";
				key = "gp";
				action = "<cmd>lua vim.lsp.buf.definition()<cr>";
				options = {desc = "Goto Definition";};
			}
			{
				mode = "n";
				key = "gP";
				action = "<cmd>lua vim.lsp.buf.type_definition()<cr>";
				options = {desc = "Goto Type Definition";};
			}
			{
				mode = ["n" "v"];
				key = "<leader>ca";
				action = "<cmd>lua vim.lsp.buf.code_action()<cr>";
				options = {desc = "Code Action";};
			}
		];
	};
}
