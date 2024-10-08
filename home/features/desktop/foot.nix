{config, ...}: let
  padding = toString config.yomi.theming.gaps.inner;
in {
  programs.foot = {
    enable = true;
    server.enable = true;
    settings = {
      main.pad = "${padding}x${padding}";
    };
  };
  stylix.targets.foot.enable = true;
}
