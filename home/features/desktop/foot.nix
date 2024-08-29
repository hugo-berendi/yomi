{
  lib,
  config,
  ...
}: let
  padding = toString config.satellite.theming.gaps.inner;
in {
  programs.foot = {
    enable = true;
    settings = {
      main.pad = "${padding}x${padding}";
    };
  };
  stylix.targets.foot.enable = true;
}
