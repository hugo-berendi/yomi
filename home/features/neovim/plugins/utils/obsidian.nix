{config, ...}: let
in {
  programs.nixvim.plugins = {
    obsidian = {
      enable = true;
      settings = {
        workspaces = [
          {
            name = "stellar-sanctum";
            path = "${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/stellar-sanctum/stellar-sanctum";
          }
        ];
        new_notes_location = "current_dir";
        completion = {
          nvim_cmp = true;
          min_chars = 2;
        };
      };
    };
  };
}
