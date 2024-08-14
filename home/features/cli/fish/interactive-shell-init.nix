{pkgs, ...}: {
  programs.fish.interactiveShellInit = ''
    source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
    source (starship init fish --print-full-init | psub)
    nerdfetch
    enable_transience
  '';
}
