{lib, ...}: {
  options.yomi.terminal = {
    command = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = "Command used to launch the preferred terminal.";
    };
    execCommand = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = "Terminal command prefix used to execute another command.";
    };
  };
}
