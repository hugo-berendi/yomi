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
    # ./pass.nix
    ./fish
    ./zoxide.nix
    ./nix-index.nix
    ./lazygit.nix
    ./cava.nix
    ./hyfetch.nix
    ./rbw.nix
    ./opencode.nix
  ];

  # Enable basic CLI thingiesMore actions
  programs.bash.enable = true;
  programs.broot.enable = true;
  programs.starship.enable = true;

  # Enable nix-index
  programs.nix-index-database.comma.enable = true;
  programs.nix-index.enable = true;
  programs.command-not-found.enable = false;

  home.packages = with pkgs; [
    # {{{ System information
    acpi # Battery stats
    nerdfetch # Display system information
    tokei # Useless but fun line of code counter (sloc alternative)
    btop # System monitor
    # }}}
    # {{{ Storage
    dua # du + ncdu replacement
    dust # Similar to du, but with prettier output
    dysk # Similar to df, but with prettier output
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
