{
	programs.nixvim.plugins.snacks = {
		enable = true;
		settings = {
			bigfile = {
				enabled = true;
			};
			dashboard = {
				enabled = true;
				preset = {
					header = ''
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣤⣤⣤⣤⣤⣤⣄⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠛⠻⠿⢿⣿⣿⣿⣿⣿⣶⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠻⣿⣿⣿⣿⣿⣿⣶⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣷⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⣙⢿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠻⣿⣿⣿⣿⣿⣿⣿⣄⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⠀⠀⢹⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⡟⠹⠿⠟⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡏⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⣿⣿⡆⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡿⠋⡬⢿⣿⣷⣤⣤⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠀⠀⠀⠀⠀⠸⣿⣿⣿⣿⣿⣿⣿⣿⡀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠰⡇⢸⡇⢸⣿⣿⣿⠟⠁⢀⣬⢽⣿⣿⣿⣿⣿⣿⠋⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣧
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣧⣈⣛⣿⣿⣿⡇⠀⠀⣾⠁⢀⢻⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿⣿⣿⣿⣿⣧⣄⣀⠙⠷⢋⣼⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⣿⣿⣿⣿⣿⣿
						⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿
						⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
						⣿⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿
						⠸⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃
						⠀⢹⣿⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀
						⠀⠀⠹⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀
						⠀⠀⠀⠙⣿⣿⣿⣿⣿⣶⣤⣀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠋⠀⠀⠀
						⠀⠀⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣷⣶⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠉⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⠀⠀⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠻⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
						⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠛⠛⠛⠛⠛⠛⠛⠋⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
					'';
				};
				sections = [
					{
						section = "header";
					}
					{
						section = "keys";
						gap = 1;
						padding = 1;
					}
					{
						pane = 2;
						section = "terminal";
						cmd = "colorscript -e square";
						height = 5;
						padding = 1;
					}
					{
						pane = 2;
						icon = " ";
						title = "Recent Files";
						section = "recent_files";
						indent = 2;
						padding = 1;
					}
					{
						pane = 2;
						icon = " ";
						title = "Projects";
						section = "projects";
						indent = 2;
						padding = 1;
					}
					{
						section = "startup";
					}
				];
			};
			indent = {
				enabled = true;
				indent = {
					char = "│";
				};
				scope = {
					enabled = true;
				};
			};
			input = {
				enabled = true;
			};
			notifier = {
				enabled = true;
				timeout = 3000;
			};
			picker = {
				enabled = true;
				win = {
					input = {
						keys = {
							["<C-j>"] = {
								"list_down";
								mode = ["i" "n"];
							};
							["<C-k>"] = {
								"list_up";
								mode = ["i" "n"];
							};
						};
					};
				};
			};
			quickfile = {
				enabled = true;
			};
			scroll = {
				enabled = true;
			};
			statuscolumn = {
				enabled = true;
			};
			terminal = {
				enabled = true;
			};
			toggle = {
				enabled = true;
			};
			words = {
				enabled = true;
			};
		};
	};

	programs.nixvim.keymaps = [
		{
			mode = "n";
			key = "<leader><space>";
			action = "<cmd>lua Snacks.picker.files()<cr>";
			options = {desc = "Find Files";};
		}
		{
			mode = "n";
			key = "<leader>/";
			action = "<cmd>lua Snacks.picker.grep()<cr>";
			options = {desc = "Grep";};
		}
		{
			mode = "n";
			key = "<leader>:";
			action = "<cmd>lua Snacks.picker.command_history()<cr>";
			options = {desc = "Command History";};
		}
		{
			mode = "n";
			key = "<leader>b";
			action = "<cmd>lua Snacks.picker.buffers()<cr>";
			options = {desc = "Buffers";};
		}
		{
			mode = "n";
			key = "<leader>fb";
			action = "<cmd>lua Snacks.picker.buffers()<cr>";
			options = {desc = "Buffers";};
		}
		{
			mode = "n";
			key = "<leader>ff";
			action = "<cmd>lua Snacks.picker.files()<cr>";
			options = {desc = "Find Files";};
		}
		{
			mode = "n";
			key = "<leader>fr";
			action = "<cmd>lua Snacks.picker.grep()<cr>";
			options = {desc = "Grep";};
		}
		{
			mode = "n";
			key = "<leader>fR";
			action = "<cmd>lua Snacks.picker.resume()<cr>";
			options = {desc = "Resume";};
		}
		{
			mode = "n";
			key = "<leader>fg";
			action = "<cmd>lua Snacks.picker.recent()<cr>";
			options = {desc = "Recent";};
		}
		{
			mode = "n";
			key = "<C-p>";
			action = "<cmd>lua Snacks.picker.git_files()<cr>";
			options = {desc = "Git Files";};
		}
		{
			mode = "n";
			key = "<leader>gc";
			action = "<cmd>lua Snacks.picker.git_log()<cr>";
			options = {desc = "Git Log";};
		}
		{
			mode = "n";
			key = "<leader>gs";
			action = "<cmd>lua Snacks.picker.git_status()<cr>";
			options = {desc = "Git Status";};
		}
		{
			mode = "n";
			key = "<leader>sa";
			action = "<cmd>lua Snacks.picker.autocmds()<cr>";
			options = {desc = "Autocmds";};
		}
		{
			mode = "n";
			key = "<leader>sb";
			action = "<cmd>lua Snacks.picker.lines()<cr>";
			options = {desc = "Buffer Lines";};
		}
		{
			mode = "n";
			key = "<leader>sc";
			action = "<cmd>lua Snacks.picker.command_history()<cr>";
			options = {desc = "Command History";};
		}
		{
			mode = "n";
			key = "<leader>sC";
			action = "<cmd>lua Snacks.picker.commands()<cr>";
			options = {desc = "Commands";};
		}
		{
			mode = "n";
			key = "<leader>sd";
			action = "<cmd>lua Snacks.picker.diagnostics_buffer()<cr>";
			options = {desc = "Document Diagnostics";};
		}
		{
			mode = "n";
			key = "<leader>sD";
			action = "<cmd>lua Snacks.picker.diagnostics()<cr>";
			options = {desc = "Workspace Diagnostics";};
		}
		{
			mode = "n";
			key = "<leader>sh";
			action = "<cmd>lua Snacks.picker.help()<cr>";
			options = {desc = "Help Pages";};
		}
		{
			mode = "n";
			key = "<leader>sH";
			action = "<cmd>lua Snacks.picker.highlights()<cr>";
			options = {desc = "Highlights";};
		}
		{
			mode = "n";
			key = "<leader>sk";
			action = "<cmd>lua Snacks.picker.keymaps()<cr>";
			options = {desc = "Keymaps";};
		}
		{
			mode = "n";
			key = "<leader>sM";
			action = "<cmd>lua Snacks.picker.man()<cr>";
			options = {desc = "Man Pages";};
		}
		{
			mode = "n";
			key = "<leader>sm";
			action = "<cmd>lua Snacks.picker.marks()<cr>";
			options = {desc = "Marks";};
		}
		{
			mode = "n";
			key = "<leader>sR";
			action = "<cmd>lua Snacks.picker.resume()<cr>";
			options = {desc = "Resume";};
		}
		{
			mode = "n";
			key = "<leader>uC";
			action = "<cmd>lua Snacks.picker.colorschemes()<cr>";
			options = {desc = "Colorscheme";};
		}
		{
			mode = "n";
			key = "<leader>qp";
			action = "<cmd>lua Snacks.picker.projects()<cr>";
			options = {desc = "Projects";};
		}
		{
			mode = "n";
			key = "<leader>un";
			action = "<cmd>lua Snacks.notifier.hide()<cr>";
			options = {desc = "Dismiss All Notifications";};
		}
		{
			mode = "n";
			key = "<leader>nh";
			action = "<cmd>lua Snacks.notifier.show_history()<cr>";
			options = {desc = "Notification History";};
		}
		{
			mode = "n";
			key = "<leader>bd";
			action = "<cmd>lua Snacks.bufdelete()<cr>";
			options = {desc = "Delete Buffer";};
		}
		{
			mode = "n";
			key = "<leader>bo";
			action = "<cmd>lua Snacks.bufdelete.other()<cr>";
			options = {desc = "Delete Other Buffers";};
		}
		{
			mode = "n";
			key = "<leader>gg";
			action = "<cmd>lua Snacks.lazygit()<cr>";
			options = {desc = "Lazygit";};
		}
		{
			mode = "n";
			key = "<leader>gb";
			action = "<cmd>lua Snacks.git.blame_line()<cr>";
			options = {desc = "Git Blame Line";};
		}
		{
			mode = "n";
			key = "<leader>gB";
			action = "<cmd>lua Snacks.gitbrowse()<cr>";
			options = {desc = "Git Browse";};
		}
		{
			mode = "n";
			key = "<leader>gf";
			action = "<cmd>lua Snacks.lazygit.log_file()<cr>";
			options = {desc = "Lazygit Current File History";};
		}
		{
			mode = "n";
			key = "<leader>gl";
			action = "<cmd>lua Snacks.lazygit.log()<cr>";
			options = {desc = "Lazygit Log";};
		}
		{
			mode = "n";
			key = "<leader>cR";
			action = "<cmd>lua Snacks.rename.rename_file()<cr>";
			options = {desc = "Rename File";};
		}
		{
			mode = "n";
			key = "<c-/>";
			action = "<cmd>lua Snacks.terminal()<cr>";
			options = {desc = "Toggle Terminal";};
		}
		{
			mode = "n";
			key = "<c-_>";
			action = "<cmd>lua Snacks.terminal()<cr>";
			options = {desc = "Toggle Terminal (which-key)";};
		}
		{
			mode = "t";
			key = "<c-/>";
			action = "<cmd>close<cr>";
			options = {desc = "Hide Terminal";};
		}
		{
			mode = "t";
			key = "<c-_>";
			action = "<cmd>close<cr>";
			options = {desc = "Hide Terminal (which-key)";};
		}
		{
			mode = "n";
			key = "]]";
			action = "<cmd>lua Snacks.words.jump(vim.v.count1)<cr>";
			options = {desc = "Next Reference";};
		}
		{
			mode = "n";
			key = "[[";
			action = "<cmd>lua Snacks.words.jump(-vim.v.count1)<cr>";
			options = {desc = "Prev Reference";};
		}
		{
			mode = ["n" "t"];
			key = "<C-h>";
			action = "<cmd>lua Snacks.terminal.toggle('horizontal')<cr>";
			options = {desc = "Terminal Horizontal";};
		}
		{
			mode = ["n" "t"];
			key = "<C-v>";
			action = "<cmd>lua Snacks.terminal.toggle('vertical')<cr>";
			options = {desc = "Terminal Vertical";};
		}
	];

	programs.nixvim.autoCmd = [
		{
			event = ["User"];
			pattern = ["VeryLazy"];
			callback = {
				__raw = ''
					function()
						_G.dd = function(...)
							Snacks.debug.inspect(...)
						end
						_G.bt = function()
							Snacks.debug.backtrace()
						end
						vim.print = _G.dd
					end
				'';
			};
		}
	];
}
