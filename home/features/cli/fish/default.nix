{pkgs, ...}: {
  imports = [
    ./shell-aliases.nix
    ./functions.nix
    ./interactive-shell-init.nix
    ./shell-init.nix
    ./login-shell-init.nix
  ];

  home.packages = with pkgs; [
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit
    fishPlugins.hydro
    fzf
    fishPlugins.grc
    grc
  ];

  programs.fish.enable = true;
  programs.fish.plugins = [
    {
      name = "done";
      src = pkgs.fetchFromGitHub {
        owner = "franciscolourenco";
        repo = "done";
        rev = "eb32ade85c0f2c68cbfcff3036756bbf27a4f366";
        sha256 = "DMIRKRAVOn7YEnuAtz4hIxrU93ULxNoQhW6juxCoh4o=";
      };
    }
  ];
}
