{
  config,
  pkgs,
  ...
}: let
  vaultDir = "${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/stellar-sanctum";

  logseqtui = pkgs.writeShellScriptBin "logseqtui" ''
    foot -a Logseq -D ${vaultDir} nvim
  '';
in {
  home.packages = [pkgs.logseq logseqtui];

  # Start nvim with a custom class so our WM can move it to the correct workspace
  xdg.desktopEntries.obsidiantui = {
    name = "LogSeq TUI";
    type = "Application";
    icon = "logseq";
    terminal = false;
    exec = "logseqtui";
  };
}
