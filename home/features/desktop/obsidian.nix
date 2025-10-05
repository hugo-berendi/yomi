{
  config,
  pkgs,
  ...
}: let
  vaultDir = "${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/stellar-sanctum/stellar-sanctum";

  obsidiantui = pkgs.writeShellScriptBin "obsidiantui" ''
    foot -a Obsidian -D ${vaultDir} nvim
  '';
in {
  # {{{ Packages
  home.packages = [pkgs.obsidian obsidiantui];
  # }}}
  # {{{ Desktop entry
  xdg.desktopEntries.obsidiantui = {
    name = "Obsidian TUI";
    type = "Application";
    icon = "obsidian";
    terminal = false;
    exec = "obsidiantui";
  };
  # }}}
}
