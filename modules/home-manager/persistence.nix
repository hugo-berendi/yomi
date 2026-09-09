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
          # }}}
          # {{{ Apps
          apps = lib.mkOption {
            default = {};
            description = "Record of gnu/stow-style groups of files/directories to be stored in this location";
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
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
            });
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
      # Home Manager's persistence module bind-mounts each directory/file at
      # the *same* relative path on both the persistent-storage side and the
      # live $HOME side, so there is no way to namespace persistent storage
      # by app name without also moving the live mount point away from where
      # programs actually expect it (eg. it would mount ~/claude-code/.claude
      # instead of ~/.claude, which nothing reads and which gets silently
      # wiped every reboot). Paths are kept verbatim to avoid that footgun.
      processPath = path: lib.strings.removePrefix "${config.home.homeDirectory}/" (builtins.toString path);
      # }}}
      # {{{ Constructors
      mkAppDirectory = app: builtins.map processPath app.directories;
      mkAppFiles = app: builtins.map processPath app.files;
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
