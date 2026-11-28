{pkgs, ...}: {
  programs.tmux = {
    enable = true;

    clock24 = true; # 24h clock format
    historyLimit = 10000; # increase amount of saved lines
    shell = "${pkgs.fish}/bin/fish";
    # Neovim reloads files changed on disk on FocusGained, which tmux only
    # forwards with focus-events on.
    focusEvents = true;

    plugins = with pkgs.tmuxPlugins; [
      sessionist # Nicer workflow for switching around between sessions
      resurrect # Save / restore tmux sessions
      {
        plugin = continuum; # Automatically restore tmux sessions
        # No @continuum-boot: it writes a user tmux.service whose ExecStop runs
        # `tmux kill-server`. fish already starts tmux, so when a switch
        # started that unit, it found the server running, exited, and its stop
        # killed every pane, including the one running the switch.
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
    ];

    extraConfig = ''
      # Main config
      source ${./tmux.conf}
    '';
  };

  stylix.targets.tmux.enable = true;

  yomi.persistence.at.state.apps.tmux.directories = [
    ".tmux"
  ];
}
