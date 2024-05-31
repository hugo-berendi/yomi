{ config, pkgs, ... }: {
    config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR = "/home/hugob/Documents";

  home.packages = let
    vaultDir =
      "${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/stellar-sanctum";
    # Start nvim with a custom class so our WM can move it to the correct workspace
    obsidiantui = pkgs.writeShellScriptBin "obsidiantui" ''
      kitty -d ${vaultDir} nvim
    '';
  in [ obsidiantui pkgs.obsidian ];

  xdg.desktopEntries.obsidiantui = {
    name = "Obsidian TUI";
    type = "Application";
    exec = "obsidiantui";
    terminal = false;
    icon = "obsidian";
  };
}
