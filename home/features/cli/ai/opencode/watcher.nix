_: {
  programs.opencode.settings = {
    # {{{ File Watcher Ignore
    watcher = {
      ignore = [
        "result"
        "result-*"
        ".git/**"
        "*.qcow2"
        ".direnv/**"
      ];
    };
    # }}}
  };
}
