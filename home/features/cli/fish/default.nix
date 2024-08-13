{...}: {
  imports = [
    ./shell-aliases.nix
    ./functions.nix
    ./interactive-shell-init.nix
    ./shell-init.nix
    ./login-shell-init.nix
  ];

  programs.fish.enable = true;
}
