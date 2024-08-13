{
  programs.fish.interactiveShellInit = ''
    source (starship init fish --print-full-init | psub)
    nerdfetch
  '';
}
