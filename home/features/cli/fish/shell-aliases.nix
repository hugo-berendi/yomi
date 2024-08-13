{
  programs.fish.shellAliases = {
    ls = "eza -al --color=always --group-directories-first --icons"; #preferred listing
    la = "eza -a --color=always --group-directories-first --icons"; #all files and dirs
    ll = "eza -l --color=always --group-directories-first --icons"; #long format
    lt = "eza -aT --color=always --group-directories-first --icons"; #tree listing
    "l." = "eza -ald --color=always --group-directories-first --icons .*"; #show only dotfiles
    lla = "eza -1 -l -a --color=always --group-directories-first --icons"; #show all at its best
    tree = "eza --tree --color=always --group-directories-first --icons"; #show tree

    cat = "bat --style header --style snip --style changes --style header";

    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    "....." = "cd ../../../..";
    "......" = "cd ../../../../..";

    big = "expac -H M \"%m\\t%n\" | sort -h | nl";
    dir = "dir --color=auto";

    tldr = "tldr --color always";
    bruh = "thefuck";

    jctl = "journalctl -p 3 -xb"; #get error messages from journalctl

    rip = "expac --timefmt=\"%Y-%m-%d %T\" \"%l\\t%n %v\" | sort | tail -200 | nl"; #recent installed packages

    yolo = "fd --type f --hidden --exclude .git | fzf-tmux -p --reverse | xargs nvim";

    upd = "~/dotfiles/nix-config/scripts/rebuild.sh";
  };
}
