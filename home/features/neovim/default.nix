{
  pkgs,
  config,
  ...
}: let
  # {{{ Client wrapper
  # Wraps a neovim client, providing the dependencies
  # and setting some flags:
  wrapClient = {
    base,
    name,
    binName ? name,
    extraArgs ? "",
  }:
    pkgs.symlinkJoin {
      inherit (base) name meta;
      paths = [base];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/${binName} \
          ${extraArgs}
      '';
    };
  # }}}
  # {{{ Clients
  neovide = wrapClient {
    base = pkgs.neovide;
    name = "neovide";
    extraArgs = "--set NEOVIDE_MULTIGRID true";
    # wrapFlags = flags: "-- ${flags}";
  };
  # }}}
in {
  # {{{ Imports
  imports = [
    ./settings.nix
    ./autocmds.nix
    ./clipboard.nix
    ./keymaps.nix
    ./colorschemes.nix
    ./plugins
  ];
  # }}}
  # {{{ nixvim config
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimdiffAlias = true;
    # package =
    #   if config.yomi.toggles.neovim-nightly.enable
    #   then pkgs.neovim-nightly
    #   else pkgs.neovim;
    viAlias = true;
    vimAlias = true;
  };
  # }}}
  yomi.lua.styluaConfig = ../../../../stylua.toml;

  # {{{ Basic config
  # We want other modules to know that we are using neovim!
  yomi.toggles.neovim.enable = true;

  # Link files in the appropriate places
  # xdg.configFile.nvim.source = config.yomi.dev.path "home/features/cli/neovim/config";
  home.sessionVariables.EDITOR = "nvim";

  home.packages = [
    neovide
    pkgs.vimclip
  ];
  # }}}
  # {{{ Persistence
  yomi.persistence.at.state.apps.neovim.directories = [
    ".local/state/nvim"
    "${config.xdg.dataHome}/nvim"
  ];

  yomi.persistence.at.cache.apps.neovim.directories = [
    "${config.xdg.cacheHome}/nvim"
    # mirosSnippetCache
  ];
  # }}}
}
