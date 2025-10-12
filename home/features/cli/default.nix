{pkgs, ...}: {
  # {{{ Imports
  imports = [
    ./scripts
    ./eza.nix
    ./bat.nix
    ./ssh.nix
    ./gpg.nix
    ./git.nix
    ./starship.nix
    ./direnv.nix
    ./tealdeer.nix
    ./tools.nix
    ./tmux
    ./yazi
    ./fish
    ./zoxide.nix
    ./nix-index.nix
    ./lazygit.nix
    ./cava.nix
    ./hyfetch.nix
    ./rbw.nix
    ./opencode.nix
    ./yubikey-scripts.nix
  ];
  # }}}
  # {{{ Basic programs
  programs.bash.enable = true;
  programs.broot.enable = true;
  programs.starship.enable = true;

  programs.nix-index-database.comma.enable = true;
  programs.nix-index.enable = true;
  programs.command-not-found.enable = false;
  # }}}
  # {{{ Packages
  home.packages = with pkgs; [
    acpi
    nerdfetch
    tokei
    btop
    dua
    dust
    dysk
    ripgrep
    fd
    sd
    httpie
    bc
    ouch
    mkpasswd
    jq
  ];
  # }}}
  # {{{ Shell aliases
  home.shellAliases = {
    df = "df -h";
    du = "du -h";
    duh = "du -hd 1";
  };
  # }}}
  # {{{ Scripts
  xdg.configFile."scripts".source = ./scripts;
  home.sessionPath = ["$HOME/.config/scripts"];
  # }}}
  # {{{ Stylix
  stylix.targets = {
    btop.enable = true;
    fzf.enable = true;
    mangohud.enable = true;
  };
  # }}}
}
