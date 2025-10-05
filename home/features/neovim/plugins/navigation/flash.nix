{
	programs.nixvim.plugins.flash = {
		enable = true;
		settings = {
			labels = "asdfghjklqwertyuiopzxcvbnm";
			search = {
				multi_window = true;
				forward = true;
				wrap = true;
				mode = "exact";
			};
			jump = {
				jumplist = true;
				pos = "start";
				history = false;
				register = false;
				nohlsearch = false;
				autojump = false;
			};
			label = {
				uppercase = true;
				rainbow = {
					enabled = false;
					shade = 5;
				};
			};
			modes = {
				search = {
					enabled = true;
				};
				char = {
					enabled = true;
					jump_labels = true;
					char_actions = ''
						function(motion)
							return {
								[";"] = "next",
								[","] = "prev",
								[motion:lower()] = "next",
								[motion:upper()] = "prev",
							}
						end
					'';
				};
				treesitter = {
					labels = "abcdefghijklmnopqrstuvwxyz";
					jump = {
						pos = "range";
					};
					search = {
						incremental = false;
					};
					label = {
						before = true;
						after = true;
						style = "inline";
					};
				};
			};
		};
	};

	programs.nixvim.keymaps = [
		{
			mode = ["n" "x" "o"];
			key = "s";
			action = "<cmd>lua require('flash').jump()<cr>";
			options = {desc = "Flash";};
		}
		{
			mode = ["n" "x" "o"];
			key = "S";
			action = "<cmd>lua require('flash').treesitter()<cr>";
			options = {desc = "Flash Treesitter";};
		}
		{
			mode = "o";
			key = "r";
			action = "<cmd>lua require('flash').remote()<cr>";
			options = {desc = "Remote Flash";};
		}
		{
			mode = ["o" "x"];
			key = "R";
			action = "<cmd>lua require('flash').treesitter_search()<cr>";
			options = {desc = "Treesitter Search";};
		}
		{
			mode = "c";
			key = "<c-s>";
			action = "<cmd>lua require('flash').toggle()<cr>";
			options = {desc = "Toggle Flash Search";};
		}
	];
}
