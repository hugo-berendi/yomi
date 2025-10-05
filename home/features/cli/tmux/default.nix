{pkgs, ...}: {
  programs.tmux = {
    enable = true;

    clock24 = true; # 24h clock format
    historyLimit = 10000; # increase amount of saved lines
    shell = "${pkgs.fish}/bin/fish";

    plugins = with pkgs.tmuxPlugins; [
      sessionist # Nicer workflow for switching around between sessions
      resurrect # Save / restore tmux sessions
      {
        plugin = continuum; # Automatically restore tmux sessions
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-boot 'on'
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
