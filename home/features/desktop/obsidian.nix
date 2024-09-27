{
  config,
  pkgs,
  ...
}: let
  vaultDir = "${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/stellar-sanctum/stellar-sanctum";

  obsidiantui = pkgs.writeShellScriptBin "obsidiantui" ''
    neovide ${vaultDir}
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
