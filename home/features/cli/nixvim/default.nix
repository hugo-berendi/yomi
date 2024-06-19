{}: {
  imports = [
    ./keymaps.nix
    ./options.nix
    ./autocmds.nix
    ./plugins
  ];

  home.shellAliases = {
    v = "nvim";
  };

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    vimdiffAlias = true;
    viAlias = true;
    vimAlias = true;

    luaLoader.enable = true;
  };
}
