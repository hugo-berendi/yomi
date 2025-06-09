{config, ...}: {
  services.mako = {
    enable = true;
    settings = {
      ignore-timeout = true;
      default-timeout = 3000;
      anchor = "bottom-right";
      border-radius = config.yomi.theming.rounding.radius;
      border-size = config.yomi.theming.rounding.size;
      margin = "0"; # outer-margin works better
      padding = "${toString (config.yomi.theming.gaps.inner / 2)}";
      outer-margin = toString config.yomi.theming.gaps.outer;
    };
  };
  stylix.targets.mako.enable = true;
}
