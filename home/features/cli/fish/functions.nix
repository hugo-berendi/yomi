{
  programs.fish.functions = {
    __history_previous_command = ''
      switch (commandline -t)
          case "!"
              commandline -t $history[1]
              commandline -f repaint
          case "*"
              commandline -i !
      end
    '';

    __history_previous_command_arguments = ''
      switch (commandline -t)
          case "!"
              commandline -t ""
              commandline -f history-token-search-backward
          case "*"
              commandline -i '$'
      end
    '';

    history = ''
      builtin history --show-time='%F %T '
    '';

    # Copy DIR1 DIR2
    copy = ''
      set count (count $argv | tr -d \n)
      if test "$count" = 2; and test -d "$argv[1]"
          set from (echo $argv[1] | string trim --right --chars=/)
          set to (echo $argv[2])
          command cp -r $from $to
      else
          command cp $argv
      end
    '';
  };
}
