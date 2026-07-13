# Taken from [misterio's config](https://github.com/Misterio77/yomi/blob/main/modules/home-manager/monitors.nix)
# This is meant to provide a wm-independent way of specifying the monitor configuration of each machine.
{lib, ...}: {
  options.yomi.monitors = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          example = "DP-1";
          description = "Monitor identifier (e.g. output name)";
        };

        width = lib.mkOption {
          type = lib.types.int;
          example = 1920;
          description = "Monitor width in pixels";
        };

        height = lib.mkOption {
          type = lib.types.int;
          example = 1080;
          description = "Monitor height in pixels";
        };

        refreshRate = lib.mkOption {
          type = lib.types.int;
          default = 60;
          description = "Refresh rate in Hz";
        };

        x = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "Monitor X position (horizontal offset in pixels)";
        };

        y = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "Monitor Y position (vertical offset in pixels)";
        };

        workspace = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Workspace to assign to this monitor (null for none)";
        };
      };
    });
  };
}
