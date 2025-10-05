{pkgs, ...}: {
	programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
		refactoring-nvim
	];

	programs.nixvim.plugins.telescope.enable = true;

	programs.nixvim.extraConfigLua = ''
		require('refactoring').setup({
			prompt_func_return_type = {
				go = false,
				java = false,
				cpp = false,
				c = false,
				h = false,
				hpp = false,
				cxx = false,
			},
			prompt_func_param_type = {
				go = false,
				java = false,
				cpp = false,
				c = false,
				h = false,
				hpp = false,
				cxx = false,
			},
			printf_statements = {},
			print_var_statements = {},
			show_success_message = true,
		})

		require('telescope').load_extension('refactoring')
	'';

	programs.nixvim.keymaps = [
		{
			mode = "x";
			key = "<leader>re";
			action = ":Refactor extract ";
			options = {desc = "Extract Function";};
		}
		{
			mode = "x";
			key = "<leader>rf";
			action = ":Refactor extract_to_file ";
			options = {desc = "Extract Function to File";};
		}
		{
			mode = "x";
			key = "<leader>rv";
			action = ":Refactor extract_var ";
			options = {desc = "Extract Variable";};
		}
		{
			mode = ["n" "x"];
			key = "<leader>ri";
			action = ":Refactor inline_var<cr>";
			options = {desc = "Inline Variable";};
		}
		{
			mode = "n";
			key = "<leader>rI";
			action = ":Refactor inline_func<cr>";
			options = {desc = "Inline Function";};
		}
		{
			mode = "n";
			key = "<leader>rb";
			action = ":Refactor extract_block<cr>";
			options = {desc = "Extract Block";};
		}
		{
			mode = "n";
			key = "<leader>rbf";
			action = ":Refactor extract_block_to_file<cr>";
			options = {desc = "Extract Block to File";};
		}
		{
			mode = ["n" "x"];
			key = "<leader>rr";
			action = "<cmd>lua require('telescope').extensions.refactoring.refactors()<cr>";
			options = {desc = "Refactor";};
		}
	];
}
