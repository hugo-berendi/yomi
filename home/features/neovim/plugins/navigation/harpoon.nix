{
	programs.nixvim.plugins.harpoon = {
		enable = true;
		enableTelescope = true;
	};

	programs.nixvim.keymaps = [
		{
			mode = "n";
			key = "<leader>a";
			action.__raw = "function() require'harpoon':list():add() end";
			options = {desc = "Harpoon Add File";};
		}
		{
			mode = "n";
			key = "<leader>h";
			action.__raw = "function() require'harpoon'.ui:toggle_quick_menu(require'harpoon':list()) end";
			options = {desc = "Harpoon Toggle Menu";};
		}
		{
			mode = "n";
			key = "<leader>j";
			action.__raw = "function() require'harpoon':list():select(1) end";
			options = {desc = "Harpoon File 1";};
		}
		{
			mode = "n";
			key = "<leader>k";
			action.__raw = "function() require'harpoon':list():select(2) end";
			options = {desc = "Harpoon File 2";};
		}
		{
			mode = "n";
			key = "<leader>l";
			action.__raw = "function() require'harpoon':list():select(3) end";
			options = {desc = "Harpoon File 3";};
		}
		{
			mode = "n";
			key = "<leader>;";
			action.__raw = "function() require'harpoon':list():select(4) end";
			options = {desc = "Harpoon File 4";};
		}
	];
}
