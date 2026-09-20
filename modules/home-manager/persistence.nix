# My own module with nicer syntax for impernanence
{
  lib,
  config,
  ...
}: let
  cfg = config.yomi.persistence;
in {
  # {{{ Option definition
  options.yomi.persistence = {
    enable = lib.mkEnableOption "yomi persistence";

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
      # {{{ Path processing
      # Impermanence v2 bind-mounts `persistentStoragePath + $HOME + path`, so
      # the live path has to stay verbatim — bending it is how you end up
      # mounting ~/claude-code/.claude, which nothing reads and which gets
      # wiped every reboot. The stow-style grouping that `removePrefixDirectory`
      # used to provide (dropped in impermanence v2, see nix-community/
      # impermanence#287) is recreated on the *storage* side instead, by giving
      # each app its own persistentStoragePath under the location.
      processPath = path: lib.strings.removePrefix "${config.home.homeDirectory}/" (builtins.toString path);

      storageFor = app:
        if location.prefixDirectories
        then "${location.path}/${app.name}"
        else location.path;
      # }}}
      # {{{ Constructors
      mkAppDirectory = app:
        builtins.map (directory: {
          directory = processPath directory;
          persistentStoragePath = storageFor app;
        })
        app.directories;

      mkAppFiles = app:
        builtins.map (file: {
          file = processPath file;
          persistentStoragePath = storageFor app;
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
  in
    lib.mkIf cfg.enable {
      home.persistence = lib.attrsets.mapAttrs' (_: makeLocation) cfg.at;
    };
  # }}}
}
