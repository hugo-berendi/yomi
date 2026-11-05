{
  lib,
  pkgs,
  ...
}: let
  texcount = lib.getExe' pkgs.texlivePackages.texcount "texcount";
in {
  programs.nvf.settings.vim = {
    # Word count of the current TeX file in the statusline (filled by the autocmd below).
    # Added at runtime: defining setupOpts.sections.lualine_x in Nix would replace
    # nvf's default entries instead of extending them.
    luaConfigRC.texcount-statusline = {
      after = ["pluginConfigs" "lazyConfigs"];
      before = [];
      data = ''
        do
        	local ok, lualine = pcall(require, "lualine")
        	if ok then
        		local config = lualine.get_config()
        		table.insert(config.sections.lualine_x, 1, {
        			function()
        				return vim.b.texcount_words or ""
        			end,
        			cond = function()
        				return vim.bo.filetype == "tex"
        			end,
        			icon = "󰈭",
        		})
        		lualine.setup(config)
        	end
        end
      '';
    };

    globals = {
      vimtex_compiler_method = "latexmk";
      vimtex_compiler_latexmk = {
        aux_dir = ".build";
        out_dir = ".build";
        callback = 1;
        continuous = 1;
        executable = "latexmk";
        options = [
          "-pdf"
          "-verbose"
          "-file-line-error"
          "-synctex=1"
          "-interaction=nonstopmode"
        ];
      };
      vimtex_complete_enabled = 1;
      vimtex_quickfix_mode = 2;
      vimtex_syntax_conceal_disable = 1;
      vimtex_view_method = "zathura";
    };

    extraPlugins.vimtex.package = pkgs.vimPlugins.vimtex;

    keymaps = [
      {
        mode = "n";
        key = "<leader>lc";
        action = "<cmd>VimtexCompile<cr>";
        desc = "Compile LaTeX";
      }
      {
        mode = "n";
        key = "<leader>lv";
        action = "<cmd>VimtexView<cr>";
        desc = "View PDF";
      }
      {
        mode = "n";
        key = "<leader>le";
        action = "<cmd>VimtexErrors<cr>";
        desc = "LaTeX Errors";
      }
      {
        mode = "n";
        key = "<leader>lt";
        action = "<cmd>VimtexTocToggle<cr>";
        desc = "LaTeX Table of Contents";
      }
      {
        mode = "n";
        key = "<leader>lk";
        action = "<cmd>VimtexStop<cr>";
        desc = "Stop LaTeX Compiler";
      }
      {
        mode = "n";
        key = "<leader>lK";
        action = "<cmd>VimtexClean<cr>";
        desc = "Clean LaTeX Build";
      }
    ];

    autocmds = [
      {
        event = ["User"];
        pattern = ["VimtexEventInitPost"];
        callback = {
          _type = "lua-inline";
          expr = ''
            function()
              vim.cmd("VimtexCompile")
            end
          '';
        };
        desc = "Start continuous LaTeX compilation";
      }
      {
        # Runs texcount asynchronously and caches the count for the statusline.
        # Only this file's running text is counted (no \input files, no headings).
        event = ["BufReadPost" "BufWritePost"];
        pattern = ["*.tex"];
        callback = {
          _type = "lua-inline";
          expr = ''
            function(args)
            	local file = vim.api.nvim_buf_get_name(args.buf)
            	if file == "" then
            		return
            	end
            	vim.system({ "${texcount}", "-1", "-utf8", "-nosub", file }, { text = true }, function(result)
            		local words = result.code == 0 and (result.stdout or ""):match("^(%d+)")
            		if not words then
            			return
            		end
            		vim.schedule(function()
            			if vim.api.nvim_buf_is_valid(args.buf) then
            				vim.b[args.buf].texcount_words = words .. " Wörter"
            				pcall(function()
            					require("lualine").refresh()
            				end)
            			end
            		end)
            	end)
            end
          '';
        };
        desc = "Count words in TeX files for the statusline";
      }
      {
        # Opt-in per repository through a `.autocommit` file at its root, so the
        # policy lives with the project (w-seminar asked for a commit on every save).
        # `add --update` keeps untracked files out: originals and transcripts there are
        # deliberately unversioned. Unsigned, because signing needs the smartcard on
        # every save.
        event = ["BufWritePost"];
        pattern = ["*"];
        callback = {
          _type = "lua-inline";
          expr = ''
            function(args)
            	local file = vim.api.nvim_buf_get_name(args.buf)
            	if file == "" then
            		return
            	end
            	local root = vim.fs.root(file, ".autocommit")
            	if not root then
            		return
            	end
            	local function fail(step, result)
            		vim.schedule(function()
            			vim.notify("Autocommit (" .. step .. "): " .. (result.stderr or ""), vim.log.levels.WARN)
            		end)
            	end
            	local git = { "git", "-C", root }
            	vim.system(vim.list_extend(vim.deepcopy(git), { "add", "--update" }), { text = true }, function(add)
            		if add.code ~= 0 then
            			return fail("add", add)
            		end
            		vim.system(vim.list_extend(vim.deepcopy(git), { "diff", "--cached", "--quiet" }), {}, function(diff)
            			if diff.code == 0 then
            				return
            			end
            			local message = "Autosave: " .. vim.fs.basename(file)
            			vim.system(
            				vim.list_extend(vim.deepcopy(git), { "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", message }),
            				{ text = true },
            				function(commit)
            					if commit.code ~= 0 then
            						fail("commit", commit)
            					end
            				end
            			)
            		end)
            	end)
            end
          '';
        };
        desc = "Commit tracked changes on save in repositories with .autocommit";
      }
    ];
  };
}
