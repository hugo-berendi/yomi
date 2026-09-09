{
  config,
  pkgs,
  ...
}: {
  home.packages = [pkgs.helium];

  xdg.mimeApps.defaultApplications = {
    "application/xhtml+xml" = ["helium.desktop"];
    "text/html" = ["helium.desktop"];
    "text/xml" = ["helium.desktop"];
    "x-scheme-handler/http" = ["helium.desktop"];
    "x-scheme-handler/https" = ["helium.desktop"];
  };

  home.sessionVariables.BROWSER = "helium";

  yomi.persistence.at.state.apps.helium.directories = [
    "${config.xdg.configHome}/helium"
  ];

  yomi.persistence.at.cache.apps.helium.directories = [
    "${config.xdg.cacheHome}/helium"
  ];
}
