{
  config,
  pkgs,
  ...
}: let
  vaultDir = "${config.xdg.userDirs.extraConfig.PROJECTS}/stellar-sanctum/stellar-sanctum";

  obsidiantui = pkgs.writeShellApplication {
    name = "obsidiantui";
    # nvim is deliberately not listed: the editor on the user's PATH is the
    # nvf-wrapped one, and a plain pkgs.neovim here would shadow it.
    runtimeInputs = [pkgs.foot];
    text = ''
      foot -a Obsidian -D ${vaultDir} nvim
    '';
  };
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
