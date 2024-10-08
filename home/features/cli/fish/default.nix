{
  pkgs,
  lib,
  config,
  ...
}: let
  repaint = "commandline -f repaint";
  fishKeybinds = {
    # C-x to clear screen
    "\\cx" = "clear && ${repaint}";
    # C-z to return to background process
    "\\cz" = "fg && ${repaint}";
    # C-y to yank current command
    "\\cy" = "wl-copy \$(commandline)";
    # C-e to launch $EDITOR
    "\\ce" = "$EDITOR";
    # C-S-e to edit commandline using $EDITOR
    "\\e\\[69\\;5u" = "edit_command_buffer";
    # C-enter to run command through a pager
    "\\e\\[13\\;2u" = "commandline -a ' | $PAGER' && commandline -f execute";
    # C-g to open lazygit
    "\\cg" = "lazygit";
    # C-S-f to open mini.files
    "\\e\\[70\\;5u" = ''nvim +":lua require('mini.files').open()"'';
  };

  mkKeybind = key: value: let
    escaped = lib.escapeShellArg value;
  in ''
    bind -M default ${key} ${escaped}
    bind -M insert  ${key} ${escaped}
  '';
in {
  imports = [
    ./shell-aliases.nix
    ./functions.nix
    ./shell-init.nix
    ./login-shell-init.nix
  ];

  # {{{ Fzf
  programs.fzf = {
    enable = true;
    defaultOptions = ["--no-scrollbar"];

    enableFishIntegration = true;
    tmux = {
      enableShellIntegration = true;
      shellIntegrationOptions = [];
    };

    changeDirWidgetOptions = ["--preview '${lib.getExe pkgs.eza} --icons --tree --color=always {}'"];

    fileWidgetOptions = ["--preview '${lib.getExe pkgs.bat} --number --color=always {}'"];
  };

  stylix.targets.fzf.enable = true;
  # }}}

  # TODO: find out why neovim needs this
  # home.file."/usr/bin/fish".source = "${pkgs.fish}/bin/fish";

  # {{{ fish
  programs.fish = {
    enable = true;
    # package = pkgs.fish;

    interactiveShellInit =
      /*
      fish
      */
      ''
        # ❄️ Fish keybinds generated using nix ^~^
        function fish_nix_key_bindings
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkKeybind fishKeybinds)}
        end

        # Modify nix-shell to use `fish` as it's default shell
        ${lib.getExe pkgs.nix-your-shell} fish | source

        # {{{ Start tmux if not already inside tmux
        if status is-interactive
        and not set -q TMUX
        and not set -q NO_TMUX
            exec tmux new-session -A -s default || tmux || echo "Something went wrong trying to start tmux"
        end
        # }}}
        source (starship init fish --print-full-init | psub)
        nerdfetch
        enable_transience

      '';

    # {{{ Plugins
    plugins = let
      plugins = with pkgs.fishPlugins; [
        # z # Jump to directories by typing "z <directory-name>"
        done # Trigger a notification when long commands finish execution
        puffer # Text expansion (i.e. expanding .... to ../../../)
        sponge # Remove failed commands and whatnot from history
        colored-man-pages
        # wakatime-fish # track fish with wakatime
        pisces # auto open and close brackets
        grc # color some commands
      ];
    in
      # For some reason home-manager expects a slightly different format 🤔
      lib.forEach plugins (plugin: {
        name = plugin.pname;
        inherit (plugin) src;
      });
    # }}}
  };

  home.packages = [pkgs.grc];

  yomi.persistence.at.state.apps.fish.directories = [
    "${config.xdg.dataHome}/fish"
    # "${config.xdg.dataHome}/z" # The z fish plugin requires this
  ];
  # }}}
}
