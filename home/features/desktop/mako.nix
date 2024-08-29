{
  config,
  lib,
  ...
}: {
  services.mako = {
    enable = true;
    ignoreTimeout = true;
    defaultTimeout = 3000;
    anchor = "bottom-right";
    borderRadius = config.satellite.theming.rounding.radius;
    borderSize = config.satellite.theming.rounding.size;
    margin = "0"; # outer-margin works better
    padding = "${toString (config.satellite.theming.gaps.inner / 2)}";
    extraConfig = ''
      outer-margin=${toString config.satellite.theming.gaps.outer}
    '';
  };
  stylix.targets.mako.enable = true;
}
