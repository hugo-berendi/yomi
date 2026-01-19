{...}: {
  programs.nvf.settings.vim.assistant = {
    copilot = {
      enable = true;
      setupOpts = {
        suggestion.enabled = false;
        panel.enabled = false;
      };
    };
    avante-nvim = {
      enable = true;
      setupOpts = {
        provider = "ollama";
        providers = {
          ollama = {
            endpoint = "http://inari:11434";
            model = "qwen2.5-coder:7b";
            timeout = 60000;
          };
        };
        behaviour = {
          auto_suggestions = false;
          auto_set_highlight_group = true;
          auto_set_keymaps = true;
          auto_apply_diff_after_generation = false;
          minimize_diff = true;
          enable_token_counting = true;
        };
        windows = {
          position = "right";
          wrap = true;
          width = 30;
          sidebar_header = {
            enabled = true;
            align = "center";
            rounded = true;
          };
        };
        hints.enabled = true;
      };
    };
  };
}
