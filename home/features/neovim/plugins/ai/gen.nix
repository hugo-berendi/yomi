{
	config,
	pkgs,
	...
}: {
	programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
		{
			plugin = pkgs.vimUtils.buildVimPlugin {
				name = "gen.nvim";
				src = pkgs.fetchFromGitHub {
					owner = "David-Kunz";
					repo = "gen.nvim";
					rev = "main";
					hash = "sha256-s12r8dvva0O2VvEPjOQvpjVpEehxsa4AWoGHXFYxQlI=";
				};
			};
		}
	];

	programs.nixvim.extraConfigLua = ''
		require('gen').setup({
			model = "qwen2.5-coder:7b",
			host = "inari",
			port = "11434",
			display_mode = "split",
			show_prompt = true,
			show_model = true,
			no_auto_close = false,
			init = function(options) pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end,
			command = function(options)
				return "curl --silent --no-buffer -X POST http://" .. options.host .. ":" .. options.port .. "/api/chat -d $body"
			end,
			debug = false
		})

		require('gen').prompts['Elaborate_Text'] = {
			prompt = "Elaborate the following text:\n$text",
			replace = true
		}
		require('gen').prompts['Fix_Code'] = {
			prompt = "Fix the following code. Only ouput the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
			replace = true,
			extract = "```$filetype\n(.-)```"
		}
		require('gen').prompts['Enhance_Code'] = {
			prompt = "Enhance the following code, only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
			replace = true,
			extract = "```$filetype\n(.-)```"
		}
		require('gen').prompts['Enhance_Grammar_Spelling'] = {
			prompt = "Modify the following text to improve grammar and spelling, just output the result in format:\n$text",
			replace = true
		}
		require('gen').prompts['Enhance_Wording'] = {
			prompt = "Modify the following text to use better wording, just output the result in format:\n$text",
			replace = true
		}
		require('gen').prompts['Make_Concise'] = {
			prompt = "Modify the following text to make it as simple and concise as possible, just output the result in format:\n$text",
			replace = true
		}
		require('gen').prompts['Make_List'] = {
			prompt = "Render the following text as a markdown list:\n$text",
			replace = true
		}
		require('gen').prompts['Make_Table'] = {
			prompt = "Render the following text as a markdown table:\n$text",
			replace = true
		}
		require('gen').prompts['Review_Code'] = {
			prompt = "Review the following code and make concise suggestions:\n```$filetype\n$text\n```",
			replace = false
		}
		require('gen').prompts['Enhance_Comment'] = {
			prompt = "Enhance the following comment, only output the result in format:\n$text",
			replace = true
		}
		require('gen').prompts['Complete_Code'] = {
			prompt = "Complete the following code, only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
			replace = true,
			extract = "```$filetype\n(.-)```"
		}
	'';

	programs.nixvim.keymaps = [
		{
			mode = ["n" "v"];
			key = "<leader>ai";
			action = ":Gen<cr>";
			options = {desc = "Gen AI";};
		}
		{
			mode = "v";
			key = "<leader>ac";
			action = ":Gen Complete_Code<cr>";
			options = {desc = "AI Complete Code";};
		}
		{
			mode = "v";
			key = "<leader>af";
			action = ":Gen Fix_Code<cr>";
			options = {desc = "AI Fix Code";};
		}
		{
			mode = "v";
			key = "<leader>ae";
			action = ":Gen Enhance_Code<cr>";
			options = {desc = "AI Enhance Code";};
		}
		{
			mode = "v";
			key = "<leader>ar";
			action = ":Gen Review_Code<cr>";
			options = {desc = "AI Review Code";};
		}
		{
			mode = "v";
			key = "<leader>ag";
			action = ":Gen Enhance_Grammar_Spelling<cr>";
			options = {desc = "AI Grammar & Spelling";};
		}
		{
			mode = "v";
			key = "<leader>aw";
			action = ":Gen Enhance_Wording<cr>";
			options = {desc = "AI Enhance Wording";};
		}
		{
			mode = "v";
			key = "<leader>as";
			action = ":Gen Make_Concise<cr>";
			options = {desc = "AI Make Concise";};
		}
	];
}
