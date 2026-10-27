{
  pkgs,
  config,
  ...
}: let
  # nvf's mnw wrapper default; check with `grep NVIM_APPNAME $(which nvim)`.
  appName = "nvf";
in {
  imports = [
    ./options.nix
    ./keymaps
    ./autocmds.nix
    ./lsp.nix
    ./treesitter.nix
    ./completion.nix
    ./writing.nix
    ./ui.nix
    ./format.nix
    ./plugins
  ];

  # {{{ nvf config
  programs.nvf = {
    enable = true;
    enableManpages = true;
    defaultEditor = true;
  };
  # }}}
  # {{{ Basic config
  home.sessionVariables.EDITOR = "nvim";
  home.packages = [pkgs.vimclip];
  # }}}
  # {{{ Persistence
  # The nvf wrapper exports NVIM_APPNAME=nvf, so undo, shada and plugin data
  # land in */nvf, not */nvim. Persisting */nvim kept nothing across reboots.
  yomi.persistence.at.state.apps.neovim.directories = [
    "${config.xdg.stateHome}/${appName}"
    "${config.xdg.dataHome}/${appName}"
  ];

  yomi.persistence.at.cache.apps.neovim.directories = [
    "${config.xdg.cacheHome}/${appName}"
  ];
  # }}}
}
