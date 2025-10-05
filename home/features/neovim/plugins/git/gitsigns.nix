{
	programs.nixvim.plugins.gitsigns = {
		enable = true;
		settings = {
			signs = {
				add = {text = "▎";};
				change = {text = "▎";};
				delete = {text = "";};
				topdelete = {text = "";};
				changedelete = {text = "▎";};
				untracked = {text = "▎";};
			};
			current_line_blame = true;
			current_line_blame_opts = {
				virt_text = true;
				virt_text_pos = "eol";
				delay = 300;
			};
			preview_config = {
				border = "rounded";
				style = "minimal";
				relative = "cursor";
				row = 0;
				col = 1;
			};
			on_attach = ''
				function(buffer)
					local gs = package.loaded.gitsigns

					local function map(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = buffer
						vim.keymap.set(mode, l, r, opts)
					end

					map("n", "]h", gs.next_hunk, { desc = "Next Hunk" })
					map("n", "[h", gs.prev_hunk, { desc = "Prev Hunk" })
					map("n", "<leader>ghs", gs.stage_hunk, { desc = "Stage Hunk" })
					map("n", "<leader>ghr", gs.reset_hunk, { desc = "Reset Hunk" })
					map("v", "<leader>ghs", function() gs.stage_hunk({vim.fn.line("."), vim.fn.line("v")}) end, { desc = "Stage Hunk" })
					map("v", "<leader>ghr", function() gs.reset_hunk({vim.fn.line("."), vim.fn.line("v")}) end, { desc = "Reset Hunk" })
					map("n", "<leader>ghS", gs.stage_buffer, { desc = "Stage Buffer" })
					map("n", "<leader>ghu", gs.undo_stage_hunk, { desc = "Undo Stage Hunk" })
					map("n", "<leader>ghR", gs.reset_buffer, { desc = "Reset Buffer" })
					map("n", "<leader>ghp", gs.preview_hunk_inline, { desc = "Preview Hunk Inline" })
					map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, { desc = "Blame Line" })
					map("n", "<leader>ghd", gs.diffthis, { desc = "Diff This" })
					map("n", "<leader>ghD", function() gs.diffthis("~") end, { desc = "Diff This ~" })
					map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "GitSigns Select Hunk" })
				end
			'';
		};
	};
}
