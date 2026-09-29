{
  config,
  pkgs,
  ...
}: let
  dark = config.stylix.polarity == "dark";

  # The simple theme draws everything from CSS variables. It sets them on
  # :root (light), :root.theme-dark and :root.theme-black, and on
  # :root.theme-auto inside a prefers-color-scheme block. Those selectors
  # all have the same specificity, so a rule appended to the stylesheet
  # beats every one of them, media query or not.
  themeCss = pkgs.writeText "searxng-yomi.css" (
    with config.lib.stylix.colors.withHashtag; ''
      :root,:root.theme-dark,:root.theme-black,:root.theme-auto{
      --color-base-font:${base05};
      --color-base-font-rgb:${config.yomi.theming.colors.rgb "base05"};
      --color-base-background:${base00};
      --color-base-background-mobile:${base00};
      --color-url-font:${base0D};
      --color-url-visited-font:${base0E};
      --color-header-background:${base01};
      --color-header-border:${base02};
      --color-footer-background:${base01};
      --color-footer-border:${base02};
      --color-sidebar-border:${base02};
      --color-sidebar-font:${base05};
      --color-sidebar-background:${base01};
      --color-backtotop-font:${base05};
      --color-backtotop-border:${base02};
      --color-backtotop-background:${base01};
      --color-btn-background:${base0D};
      --color-btn-font:${base00};
      --color-show-btn-background:${base02};
      --color-show-btn-font:${base05};
      --color-search-border:${base02};
      --color-search-background:${base01};
      --color-search-font:${base05};
      --color-search-background-hover:${base0D};
      --color-error:${base08};
      --color-error-background:${base01};
      --color-warning:${base0A};
      --color-warning-background:${base01};
      --color-success:${base0B};
      --color-success-background:${base01};
      --color-categories-item-selected-font:${base0D};
      --color-categories-item-border-selected:${base0D};
      --color-autocomplete-font:${base05};
      --color-autocomplete-border:${base02};
      --color-autocomplete-background:${base01};
      --color-autocomplete-background-hover:${base02};
      --color-answer-font:${base05};
      --color-answer-background:${base01};
      --color-result-keyvalue-col-table:${base01};
      --color-result-keyvalue-odd:${base01};
      --color-result-keyvalue-even:${base00};
      --color-result-background:${base01};
      --color-result-border:${base02};
      --color-result-url-font:${base05};
      --color-result-vim-selected:${base02};
      --color-result-vim-arrow:${base0D};
      --color-result-description-highlight-font:${base06};
      --color-result-link-font:${base0D};
      --color-result-link-font-highlight:${base0D};
      --color-result-link-visited-font:${base0E};
      --color-result-publishdate-font:${base04};
      --color-result-engines-font:${base04};
      --color-result-search-url-border:${base02};
      --color-result-search-url-font:${base05};
      --color-result-detail-font:${base05};
      --color-result-detail-label-font:${base04};
      --color-result-detail-background:${base00};
      --color-result-detail-hr:${base02};
      --color-result-detail-link:${base0D};
      --color-result-image-span-font:${base05};
      --color-result-image-span-font-selected:${base00};
      --color-result-image-background:${base01};
      --color-settings-tr-hover:${base02};
      --color-settings-engine-description-font:${base04};
      --color-settings-table-group-background:${base01};
      --color-toolkit-badge-font:${base00};
      --color-toolkit-badge-background:${base03};
      --color-toolkit-kbd-font:${base00};
      --color-toolkit-kbd-background:${base05};
      --color-toolkit-dialog-border:${base02};
      --color-toolkit-dialog-background:${base01};
      --color-toolkit-tabs-label-border:${base00};
      --color-toolkit-tabs-section-border:${base02};
      --color-toolkit-select-background:${base02};
      --color-toolkit-select-border:${base03};
      --color-toolkit-select-background-hover:${base03};
      --color-toolkit-input-text-font:${base05};
      --color-toolkit-checkbox-onoff-off-background:${base02};
      --color-toolkit-checkbox-onoff-on-background:${base02};
      --color-toolkit-checkbox-onoff-on-mark-background:${base0D};
      --color-toolkit-checkbox-onoff-on-mark-color:${base00};
      --color-toolkit-checkbox-onoff-off-mark-background:${base04};
      --color-toolkit-checkbox-onoff-off-mark-color:${base00};
      --color-toolkit-checkbox-label-background:${base00};
      --color-toolkit-checkbox-label-border:${base02};
      --color-toolkit-checkbox-input-border:${base0D};
      --color-toolkit-engine-tooltip-border:${base02};
      --color-toolkit-engine-tooltip-background:${base01};
      --color-doc-code:${base05};
      --color-doc-code-background:${base02};
      --color-favicon-background-color:${base02};
      --color-favicon-border-color:${base03};
      }
    ''
  );
  accent = config.lib.stylix.colors.withHashtag.base0D;

  # SearXNG has no custom-CSS setting, but ui.static_path swaps the whole
  # static tree. Serve a copy with the override appended, instead of
  # rebuilding the package.
  static = pkgs.runCommand "searxng-static-yomi" {nativeBuildInputs = [pkgs.imagemagick];} ''
    cp -r --no-preserve=mode ${config.services.searx.package}/lib/python3*/site-packages/searx/static $out
    for css in $out/themes/simple/sxng-{ltr,rtl}.min.css; do
      cat ${themeCss} >> "$css"
    done

    # The logo and favicon hard-code SearXNG blue rather than use a variable,
    # and the pages mostly load PNG renders of them (the start page through
    # CSS, the preferences header through an <img>). Recolour both. The PNGs
    # are one colour with alpha-only antialiasing, so painting every pixel
    # the accent while keeping alpha keeps their edges and padding intact.
    img=$out/themes/simple/img
    sed -i -e 's/#487cff/${accent}/gI' -e 's/#3050ff/${accent}/gI' $img/{searxng,favicon}.svg
    for png in $img/{searxng,favicon,192,512}.png; do
      magick "$png" -fill '${accent}' -colorize 100 "PNG32:$png"
    done
  '';
in {
  services.searx.settings.ui = {
    static_path = "${static}";
    # Only the code-highlight colours still follow the style; match them
    # to the palette the variables above come from.
    theme_args.simple_style =
      if dark
      then "dark"
      else "light";
  };
}
