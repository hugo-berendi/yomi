{...}: {
  programs.opencode.settings = {
    # {{{ Permissions - Allow skills, safe bash commands
    permission = {
      skill."*" = "allow";
      bash = {
        "*" = "allow";
        "git push*" = "ask";
        "git reset --hard*" = "ask";
        "just nixos-rebuild switch*" = "ask";
        "rm -rf*" = "ask";
        "sudo*" = "ask";
      };
    };
    # }}}
  };
}
