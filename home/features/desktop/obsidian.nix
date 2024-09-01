{
  config,
  pkgs,
  ...
}: let
  vaultDir = "${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/stellar-sanctum";

  obsidiantui = pkgs.writeShellScriptBin "obsidiantui" ''
    foot -a Obsidian -D ${vaultDir} nvim
  '';
in {
  home.packages = [pkgs.obsidian obsidiantui];

  # Start nvim with a custom class so our WM can move it to the correct workspace
  xdg.desktopEntries.obsidiantui = {
    name = "Obsidian TUI";
    type = "Application";
    icon = "obsidian";
    terminal = false;
    exec = "obsidiantui";
  };
}
