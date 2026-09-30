# Home persistence grouped by application.
{
  lib,
  config,
  ...
}: let
  cfg = config.yomi.persistence;
  # Impermanence v2 binds the original live path. App grouping belongs on
  # the storage side, through persistentStoragePath, rather than in the path
  # applications read. See nix-community/impermanence#287.
  processPath = path: lib.strings.removePrefix "${config.home.homeDirectory}/" (builtins.toString path);
  storageFor = location: app:
    if location.prefixDirectories
    then "${location.path}/${app.name}"
    else location.path;
  localBackupExcludes = lib.concatMap (location: let
    persisted = config.home.persistence.${location.home};
  in
    lib.concatMap (app:
      map (d: d.persistentStoragePath + d.dirPath)
      (lib.filter (d: d.persistentStoragePath == storageFor location app && lib.elem d.directory (map processPath app.directories)) persisted.directories)
      ++ map (f: f.persistentStoragePath + f.filePath)
      (lib.filter (f: f.persistentStoragePath == storageFor location app && lib.elem f.file (map processPath app.files)) persisted.files))
    (lib.filter (app: app.excludeFromLocalBackups) (lib.attrValues location.apps)))
  (lib.attrValues cfg.at);
in {
  # {{{ Option definition
  options.yomi.persistence = {
    enable = lib.mkEnableOption "yomi persistence";
    localBackupExcludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Physical storage paths explicitly omitted from local Restic backups.";
    };

    at = lib.mkOption {
      default = {};
      description = "Record of persistent locations (eg: /persist)";
      type = lib.types.attrsOf (lib.types.submodule (args: {
        config = {
          home = args.config.path;
        };

        options = {
          # {{{ Location options
          path = lib.mkOption {
            type = lib.types.str;
            example = "/persist";
            description = "The root location to store the home directory for files in this record";
          };

          home = lib.mkOption {
            type = lib.types.str;
            description = "The path to the home directory for files in this record";
          };

          prefixDirectories = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether to give every app its own gnu/stow-style subdirectory in
              persistent storage, so an app's state can be inspected or wiped
              as a unit instead of being scattered through a shared home.
            '';
          };
          # }}}
          # {{{ Apps
          apps = lib.mkOption {
            default = {};
            description = "Record of gnu/stow-style groups of files/directories to be stored in this location";
            type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = "The gnu/stow-style subdirectory name";
                };

                excludeFromLocalBackups = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Omit this application's persisted directories and files from local Restic backups.";
                };

                files = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  example = [".screenrc"];
                  description = ''
                    A list of files in your home directory you want to
                    link to persistent storage. Allows both absolute paths
                    and paths relative to the home directory.
                  '';
                };

                directories = lib.mkOption {
                  default = [];
                  description = ''
                    Modified version of `home.persistence.*.directories` which takes in absolute paths.
                  '';
                  type = lib.types.listOf lib.types.str;
                };
              };
            }));
          };
          # }}}
        };
      }));
    };
  };
  # }}}
  # {{{ Config generation
  config = let
    makeLocation = location: let
      # {{{ Constructors
      mkAppDirectory = app:
        builtins.map (directory: {
          directory = processPath directory;
          persistentStoragePath = storageFor location app;
        })
        app.directories;

      mkAppFiles = app:
        builtins.map (file: {
          file = processPath file;
          persistentStoragePath = storageFor location app;
        })
        app.files;
      # }}}
    in
      # {{{ Impermanence config generation
      lib.attrsets.nameValuePair location.home {
        directories =
          lib.lists.flatten
          (lib.attrsets.mapAttrsToList (_: mkAppDirectory) location.apps);

        files =
          lib.lists.flatten
          (lib.attrsets.mapAttrsToList (_: mkAppFiles) location.apps);
      };
    # }}}
  in {
    yomi.persistence.localBackupExcludes = lib.optionals cfg.enable localBackupExcludes;
    home.persistence = lib.mkIf cfg.enable (lib.attrsets.mapAttrs' (_: makeLocation) cfg.at);
  };
  # }}}
}
