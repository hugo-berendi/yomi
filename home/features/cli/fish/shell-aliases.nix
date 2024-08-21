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

    dir = "dir --color=auto";

    tldr = "tldr --color always";
    bruh = "thefuck";

    jctl = "journalctl -p 3 -xb"; #get error messages from journalctl

    yolo = "fd --type f --hidden --exclude .git | fzf-tmux -p --reverse | xargs nvim";

    upd = "~/Projects/nix-config/scripts/rebuild.sh";

    # cd = "zoxide";
  };
}
