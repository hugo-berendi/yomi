{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  korora = inputs.korora.lib;
  nlib =
    import ../../../../modules/common/korora-neovim.nix
    {inherit lib korora;}
    {tempestModule = "my.tempest";};

  generated =
    nlib.generateConfig
    (lib.fix (self: with nlib; {}));
  # Experimental nix module generation
  generatedConfig =
    config.satellite.lib.lua.writeFile
    "lua/nix" "init"
    generated.lua;

  extraRuntime = lib.concatStringsSep "," [
    generatedConfig
    # mirosSnippetCache
    "${pkgs.vimPlugins.lazy-nvim}"
  ];

  # }}}
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
    # startupScript =
    #   config.satellite.lib.lua.writeFile
    #   "." "startup"
    #   /*
    #   lua
    #   */
    #   ''
    #     -- vim.g.nix_extra_runtime = ${nlib.encode extraRuntime}
    #     vim.g.nix_projects_dir = ${nlib.encode config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}
    #     vim.g.nix_theme = ${config.satellite.colorscheme.lua}
    #     -- Provide hints as to what app we are running in
    #     -- (Useful because neovide does not provide the info itself right away)
    #     vim.g.nix_neovim_app = ${nlib.encode name}
    #   '';
    # extraFlags =
    #   lib.escapeShellArg (wrapFlags
    #     ''-u ~/.config/nvim/init.lua'');
  in
    pkgs.symlinkJoin {
      inherit (base) name meta;
      paths = [base];
      nativeBuildInputs = [pkgs.makeWrapper];

      # --prefix PATH : ${lib.makeBinPath generated.dependencies} \

      # --add-flags ${extraFlags} \
      postBuild = ''
        wrapProgram $out/bin/${binName} \
          ${extraArgs}
      '';
    };
  # }}}
  # {{{ Clients
  neovim = wrapClient {
    base =
      if config.satellite.toggles.neovim-nightly.enable
      then pkgs.neovim
      else pkgs.unstable.neovim;
    name = "nvim";
  };

  neovide = wrapClient {
    base = pkgs.neovide;
    name = "neovide";
    extraArgs = "--set NEOVIDE_MULTIGRID true";
    wrapFlags = flags: "-- ${flags}";
  };
  # }}}
in {
  satellite.lua.styluaConfig = ../../../../stylua.toml;

  # {{{ Basic config
  # We want other modules to know that we are using neovim!
  satellite.toggles.neovim.enable = true;

  # Link files in the appropriate places
  xdg.configFile.nvim.source = config.satellite.dev.path "home/features/cli/neovim/config";
  home.sessionVariables.EDITOR = "nvim";

  home.packages = [
    neovim
    neovide
    pkgs.vimclip
  ];
  # }}}
  # {{{ Persistence
  satellite.persistence.at.state.apps.neovim.directories = [
    ".local/state/nvim"
    "${config.xdg.dataHome}/nvim"
  ];

  satellite.persistence.at.cache.apps.neovim.directories = [
    "${config.xdg.cacheHome}/nvim"
    # mirosSnippetCache
  ];
  # }}}
}
