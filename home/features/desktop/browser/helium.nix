{
  config,
  pkgs,
  ...
}: let
  extensions = import ./extensions.nix;
  extensionUpdateUrl = "https://clients2.google.com/service/update2/crx";
in {
  home.packages = [pkgs.helium];

  xdg.configFile = builtins.listToAttrs (map (id: {
      name = "net.imput.helium/External Extensions/${id}.json";
      value.text = builtins.toJSON {external_update_url = extensionUpdateUrl;};
    })
    extensions);

  xdg.mimeApps.defaultApplications = {
    "application/xhtml+xml" = ["helium.desktop"];
    "text/html" = ["helium.desktop"];
    "text/xml" = ["helium.desktop"];
    "x-scheme-handler/http" = ["helium.desktop"];
    "x-scheme-handler/https" = ["helium.desktop"];
  };

  home.sessionVariables.BROWSER = "helium";

  yomi.persistence.at.state.apps.helium.directories = [
    "${config.xdg.configHome}/net.imput.helium"
  ];

  yomi.persistence.at.cache.apps.helium.directories = [
    "${config.xdg.cacheHome}/net.imput.helium"
  ];
}
