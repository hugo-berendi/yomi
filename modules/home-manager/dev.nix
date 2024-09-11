{
  lib,
  config,
  ...
}: {
  options.yomi.dev = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "While true, makes out of store symlinks for files in dev mode";
    };

    root = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/nix-config";
      description = "Where the yomi repo is cloned";
    };

    path = lib.mkOption {
      type = lib.types.functionTo lib.types.path;
      description = "The function used to conditionally symlink in or out of store based on the above paths";
    };
  };

  config.yomi.dev.path = path:
    if config.yomi.dev.enable
    then config.lib.file.mkOutOfStoreSymlink "${config.yomi.dev.root}/${path}"
    else "${../..}/${path}";
}
