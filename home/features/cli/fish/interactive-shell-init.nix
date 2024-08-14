{pkgs, ...}: {
  programs.fish.interactiveShellInit = ''
    if not set -q TMUX
        tmux attach -t default || tmux new -s default
    end
    source (starship init fish --print-full-init | psub)
    nerdfetch
    enable_transience
  '';
}
