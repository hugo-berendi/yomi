{
  config,
  lib,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors;
  package = pkgs.grafana;
  palette = with colors.withHashtag; {
    "#111217" = base00;
    "#181b1f" = base01;
    "#22252b" = base02;
    "#3d71d9" = base0D;
    "#6e9fff" = base0C;
  };
  replace = replacements:
    lib.concatStringsSep " " (lib.mapAttrsToList (old: new: "--replace-fail ${lib.escapeShellArg old} ${lib.escapeShellArg new}")
      replacements);
in {
  services.grafana = {
    settings.users.default_theme = "dark";
    package = pkgs.symlinkJoin {
      name = "grafana-stylix-${package.version}";
      inherit (package) version meta;
      paths = [package];
      postBuild = ''
        assets="$out/share/grafana/public/build"
        shopt -s nullglob
        styles=("$assets"/grafana.dark.*.css "$assets"/grafana.dark-react19.*.css)
        test "''${#styles[@]}" -gt 0
        for asset in "''${styles[@]}"; do
          substitute "$asset" "$asset.stylix" ${replace (palette // {"#ccccdc" = colors.withHashtag.base05;})}
          mv -T "$asset.stylix" "$asset"
        done

        # Grafana also constructs the dark theme at runtime for React and charts.
        mapfile -t bundles < <(rg -l -F 'gray05:"#111217",gray10:"#181b1f"' "$assets" -g '*.js' --follow)
        test "''${#bundles[@]}" -gt 0
        for asset in "''${bundles[@]}"; do
          substitute "$asset" "$asset.stylix" ${replace (palette
          // {
            "204, 204, 220" = "${colors.base05-rgb-r}, ${colors.base05-rgb-g}, ${colors.base05-rgb-b}";
          })}
          mv -T "$asset.stylix" "$asset"
        done
      '';
      nativeBuildInputs = [pkgs.ripgrep];
    };
  };
}
