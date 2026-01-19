{
  pkgs,
  config,
  lib,
  ...
}: let
  # {{{ Client wrapper
  wrapClient = {
    base,
    name,
    binName ? name,
    extraArgs ? "",
    wrapFlags ? lib.id,
  }: let
    startupScript =
      config.yomi.lib.lua.writeFile "." "startup"
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
  # {{{ Neovide client
  neovide = wrapClient {
    base = pkgs.neovide;
    name = "neovide";
    extraArgs = "--set NEOVIDE_MULTIGRID true";
    wrapFlags = flags: "-- ${flags}";
  };
  # }}}
in {
  imports = [
    ./options.nix
    ./keymaps.nix
    ./autocmds.nix
    ./lsp.nix
    ./treesitter.nix
    ./completion.nix
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
  # {{{ Lua stylua config for this project
  yomi.lua.styluaConfig = ../../../stylua.toml;
  # }}}
  # {{{ Basic config
  yomi.toggles.neovim.enable = true;
  home.sessionVariables.EDITOR = "nvim";
  home.packages = [pkgs.vimclip];

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
  ];
  # }}}
}
