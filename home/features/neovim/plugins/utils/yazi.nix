{
  programs.nixvim = {
    plugins.yazi = {
      enable = true;
      settings = {
        enable_mouse_support = false;
        clipboard_register = "*"; # system clipboard
        floating_window_scaling_factor = 0.8;
        log_level = "debug";
        open_for_directories = true;
        yazi_floating_window_border = "single";
        yazi_floating_window_winblend = 0;
        keymaps = {
          copy_relative_path_to_selected_files = "<c-y>";
          cycle_open_buffers = "<tab>";
          grep_in_directory = "<c-s>";
          open_file_in_horizontal_split = "<c-x>";
          open_file_in_tab = "<c-t>";
          open_file_in_vertical_split = "<c-v>";
          replace_in_directory = "<c-g>";
          send_to_quickfix_list = "<c-q>";
          show_help = "<f1>";
        };
      };
    };
    keymaps = [
      {
        mode = "n";
        key = "<leader>fe";
        action = "<cmd>Yazi<cr>";
        options = {
          desc = "Open yazi at the current file";
        };
      }
      {
        mode = "n";
        key = "<leader>fE";
        action = "<cmd>Yazi cwd<cr>";
        options = {
          desc = "Open the file manager in nvim's working directory";
        };
      }
    ];
  };
}
