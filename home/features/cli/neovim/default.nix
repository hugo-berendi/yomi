{
  pkgs,
  upkgs,
  config,
  ...
}: let
  # Experimental nix module generation
  # }}}
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
      if config.yomi.toggles.neovim-nightly.enable
      then pkgs.neovim
      else upkgs.neovim;
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
  yomi.lua.styluaConfig = ../../../../stylua.toml;

  # {{{ Basic config
  # We want other modules to know that we are using neovim!
  yomi.toggles.neovim.enable = true;

  # Link files in the appropriate places
  xdg.configFile.nvim.source = config.yomi.dev.path "home/features/cli/neovim/config";
  home.sessionVariables.EDITOR = "nvim";

  home.packages = [
    neovim
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
