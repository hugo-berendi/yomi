{config, ...}: {
  services.mako = {
    enable = true;
    ignoreTimeout = true;
    defaultTimeout = 3000;
    anchor = "bottom-right";
    borderRadius = config.yomi.theming.rounding.radius;
    borderSize = config.yomi.theming.rounding.size;
    margin = "0"; # outer-margin works better
    padding = "${toString (config.yomi.theming.gaps.inner / 2)}";
    extraConfig = ''
      outer-margin=${toString config.yomi.theming.gaps.outer}
    '';
  };
  stylix.targets.mako.enable = true;
}
