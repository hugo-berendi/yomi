{
	programs.nixvim.plugins = {
		blink-cmp-copilot.enable = true;
		copilot-lua = {
			enable = true;
			settings = {
				suggestion = {enabled = false;};
				panel = {enabled = false;};
			};
		};
	};
}
