{
  pkgs,
  upkgs,
  config,
  lib,
  inputs,
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
    wrapFlags ? lib.id,
  }: let
    startupScript =
      config.yomi.lib.lua.writeFile "." "startup" # lua
      
      ''
        vim.g.nix_theme = ${config.yomi.colorscheme.lua}
      '';

    extraFlags = lib.escapeShellArg (wrapFlags ''--cmd "lua dofile('${startupScript}/startup.lua')"'');
  in
    pkgs.symlinkJoin {
      inherit (base) name meta;
      paths = [base];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/${binName} \
          --add-flags ${extraFlags} \
          ${extraArgs}
      '';
    };
  # }}}
  # {{{ Clients
  neovide = wrapClient {
    base = pkgs.neovide;
    name = "neovide";
    extraArgs = "--set NEOVIDE_MULTIGRID true";
    wrapFlags = flags: "-- ${flags}";
  };

  neovim =
    if config.yomi.toggles.neovim-nightly.enable
    then inputs.neovim-nightly-overlay.packages.${pkgs.system}.default
    else pkgs.neovim-unwrapped;
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
    package = neovim;
    viAlias = true;
    vimAlias = true;
  };
  # }}}
  yomi.lua.styluaConfig = ../../../stylua.toml;

  # {{{ Basic config
  # We want other modules to know that we are using neovim!
  yomi.toggles.neovim.enable = true;

  # Link files in the appropriate places
  # xdg.configFile.nvim.source = config.yomi.dev.path "home/features/cli/neovim/config";
  home.sessionVariables.EDITOR = "nvim";

  home.packages = [
    pkgs.vimclip
  ];

  programs.neovide = {
    enable = false;
    package = neovide;
    settings = {
      fork = false;
      frame = "full";
      idle = true;
      maximized = false;
      no-multigrid = false;
      srgb = false;
      tabs = true;
      theme = "auto";
      title-hidden = true;
      vsync = true;
      wsl = false;

      font = {
        normal = ["${config.stylix.fonts.monospace.name}"];
        bold = ["${config.stylix.fonts.monospace.name}"];
        italic = ["${config.stylix.fonts.monospace.name}"];
        bold_italic = ["${config.stylix.fonts.monospace.name}"];
        size = config.stylix.fonts.sizes.terminal;
      };
    };
  };
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
