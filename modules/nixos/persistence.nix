{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.persistence;
  directory = lib.types.submodule {
    options = {
      directory = lib.mkOption {
        type = lib.types.str;
        description = "Absolute live directory path.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "Directory owner.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "Directory group.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "0755";
        description = "Directory permissions.";
      };
    };
  };
  entries = lib.concatLists (lib.mapAttrsToList (
      location: loc:
        lib.mapAttrsToList (app: value: {
          inherit location app;
          inherit (loc) path;
          inherit (value) directories files backupSets;
        })
        loc.apps
    )
    cfg.at);
in {
  options.yomi.persistence = {
    at = lib.mkOption {
      default = {};
      description = "System persistence locations grouped by application; backup selection is explicit.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Absolute backing storage mount.";
          };
          apps = lib.mkOption {
            default = {};
            description = "Application persistence declarations.";
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                directories = lib.mkOption {
                  type = lib.types.listOf directory;
                  default = [];
                  description = "Directories and their ownership.";
                };
                files = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = "Absolute live file paths.";
                };
                backupSets = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = "Named yomi.restic.sets explicitly receiving these live paths.";
                };
              };
            });
          };
        };
      });
    };
    inventory = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      description = "Evaluated application paths, ownership and explicit backup assignments.";
    };
  };
  config = {
    yomi.persistence.inventory = entries;
    environment.persistence = lib.mkMerge (map (entry: {
        ${entry.path} = {inherit (entry) directories files;};
      })
      entries);
    yomi.restic.sets = lib.mkMerge (map (entry:
      lib.genAttrs entry.backupSets (_: {
        paths = (map (d: d.directory) entry.directories) ++ entry.files;
      }))
    entries);
    assertions = lib.concatMap (entry:
      [
        {
          assertion = lib.hasPrefix "/" entry.path && lib.all (p: lib.hasPrefix "/" p) ((map (d: d.directory) entry.directories) ++ entry.files);
          message = "Persistence paths for ${entry.app} must be absolute.";
        }
      ]
      ++ map (set: {
        assertion = config.yomi.restic.enable && config.yomi.restic.sets.${set}.enable;
        message = "Persistence backup assignment ${entry.app} requires enabled restic set ${set}.";
      })
      entry.backupSets)
    entries;
  };
}
