{pkgs, ...}: {
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
    # ./neovim
    ./pass.nix
    ./fish
    ./zoxide.nix
    ./nix-index.nix
    ./lazygit.nix
    ./cava.nix
    ./hyfetch.nix
  ];

  programs.bash.enable = true;

  home.packages = with pkgs; [
    # {{{ System information
    acpi # Battery stats
    nerdfetch # Display system information
    tokei # Useless but fun line of code counter (sloc alternative)
    btop # System monitor
    # }}}
    # {{{ Storage
    ncdu # TUI disk usage
    du-dust # Similar to du and ncdu in purpose.
    # }}}
    # {{{ Alternatives to usual commands
    ripgrep # Better grep
    fd # Better find
    sd # Better sed
    httpie # Better curl
    # }}}
    # {{{ Misc
    bc # Calculator
    ouch # Unified compression / decompression tool
    mkpasswd # Hash passwords
    jq # Json maniuplation
    # }}}
  ];

  home.shellAliases = {
    # {{{ Storage
    # -h = humans readable units
    df = "df -h";
    du = "du -h";

    # short for `du here`
    # -d = depth
    duh = "du -hd 1";
    # }}}
  };

  xdg.configFile."scripts".source = ./scripts;
  home.sessionPath = ["$HOME/.config/scripts"];

  stylix.targets = {
    btop.enable = true;
    fzf.enable = true;
    mangohud.enable = true;
  };
}
