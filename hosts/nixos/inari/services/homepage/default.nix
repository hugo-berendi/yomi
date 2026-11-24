{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.homepage;

  # {{{ Tiles
  # Groups and their tiles per row. The page shows the groups by name
  # (Entertainment, Media, Tooling): homepage follows settings.layout, and
  # Nix writes an attribute set in name order.
  groups = [
    {
      name = "Tooling";
      columns = 3;
    }
    {
      name = "Media";
      columns = 4;
    }
    {
      name = "Entertainment";
      columns = 3;
    }
  ];
  groupNames = map (g: g.name) groups;

  # An endpoint declares its own tile with yomi.web.at.<name>.homepage, beside
  # the rest of the service. Only tiles that are not an endpoint of their own
  # are listed here.
  extraTiles = [
    {
      group = "Tooling";
      name = "Infrastrukturkarte";
      icon = "mdi-sitemap";
      href = "${config.yomi.web.at.lab.url}/infrastruktur/";
      description = "Hosts, Dienste und Verbindungen";
      widget = null;
    }
    {
      group = "Tooling";
      name = "SimpleLogin";
      icon = "mdi-email-fast-outline";
      href = "https://app.simplelogin.io";
      description = "Email aliasing";
      widget = null;
    }
  ];

  tiles =
    extraTiles
    ++ lib.mapAttrsToList (_: e: {
      inherit (e.homepage) group name icon description widget;
      href = e.url;
    }) (lib.filterAttrs (_: e: e.enable && e.homepage != null) config.yomi.web.at);
  unknownGroups = lib.filter (t: !lib.elem t.group groupNames) tiles;

  tile = t: {
    ${t.name} =
      {inherit (t) icon href description;}
      // lib.optionalAttrs (t.widget != null) {inherit (t) widget;};
  };
  group = g: {
    ${g.name} =
      map tile (lib.sort (a: b: lib.toLower a.name < lib.toLower b.name)
        (lib.filter (t: t.group == g.name) tiles));
  };
  # }}}
in {
  # {{{ Ports
  yomi.ports = {
    homepage = 8415;
  };
  # }}}
  imports = [./infrastructure-topology.nix];

  sops.secrets.homepage_env = {
    sopsFile = ../../secrets.yaml;
  };

  yomi.web.at.lab = {
    inherit port;
    transport = "nginx";
    authentication = "none";
    monitor.enable = true;
  };

  assertions = [
    {
      assertion = unknownGroups == [];
      message = "Homepage tiles ${lib.concatMapStringsSep ", " (t: "${t.name} (group ${t.group})") unknownGroups} name a group the dashboard does not lay out; use one of ${lib.concatStringsSep ", " groupNames}, or add the group to `groups` in services/homepage/default.nix.";
    }
  ];

  services.homepage-dashboard = {
    enable = true;
    listenPort = port;
    environmentFiles = [config.sops.secrets.homepage_env.path];

    settings = {
      title = "✨ The celestial citadel ✨";
      headerStyle = "clean";
      color = "slate";
      layout = lib.listToAttrs (map (g:
        lib.nameValuePair g.name {
          style = "row";
          inherit (g) columns;
        })
      groups);
    };

    customCSS = with config.lib.stylix.colors.withHashtag; ''
      body {
      	background-color: ${base00};
      	color: ${base05};
      }
      .service-card {
      	background-color: ${base01};
      	border-color: ${base03};
      }
      .service-card:hover {
      	background-color: ${base02};
      	border-color: ${base0D};
      }
      h1, h2, h3, h4, h5, h6 {
      	color: ${base0D};
      }
    '';

    services = map group groups;

    bookmarks = [
      {
        Development = [
          {
            Github = [
              {
                abbr = "GH";
                href = "https://github.com/hugo-berendi/yomi";
              }
            ];
          }
        ];
      }
    ];

    widgets = [
      {
        datetime = {
          text_size = "xl";
          format = {
            dateStyle = "long";
            timeStyle = "short";
            hour12 = false;
          };
        };
      }
      {
        openmeteo = {
          label = "Feldkirchen-Westerham";
          latitude = 47.9167;
          longitude = 11.9167;
          units = "metric";
          cache = 5;
        };
      }
      {
        greeting = {
          text_size = "xl";
          text = "Welcome to the celestial citadel";
        };
      }
    ];
  };
}
