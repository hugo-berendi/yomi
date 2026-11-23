_: {
  programs.opencode.settings = {
    # {{{ Compaction - Auto-compact and prune for efficiency
    compaction = {
      auto = true;
      prune = true;
    };
    # }}}
  };
}
