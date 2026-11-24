# Every yomi.* option, as the Markdown in docs/options.md. `just docs`
# rewrites that file from this; the options-doc check fails when the
# committed copy no longer matches what the modules declare.
{
  pkgs,
  self,
}: let
  inherit (pkgs) lib;
  hosts = builtins.removeAttrs self.nixosConfigurations ["iso"];

  # Options are declared in modules, profiles, home and some hosts, so
  # take each host's yomi tree and keep the first declaration of each name.
  nixosYomi = lib.foldl' (acc: host: (host.options.yomi or {}) // acc) {} (builtins.attrValues hosts);

  # Home Manager options come from the pilot's submodule on a host that has
  # every Home Manager feature in play, evaluated with the modules that host
  # gives it.
  homeYomi = let
    users = self.nixosConfigurations.amaterasu.options.home-manager.users;
    elem = users.type.nestedTypes.elemType;
    pilot = self.nixosConfigurations.amaterasu.config.yomi.pilot.name;
    userModules = lib.concatMap (d:
      lib.optional (builtins.isAttrs d.value && d.value ? ${pilot}) {
        _file = d.file;
        imports = [d.value.${pilot}];
      })
    users.definitionsWithLocations;
    all = ((elem.substSubModules (elem.getSubModules ++ userModules)).getSubOptions []).yomi;
    # pilot, theming and friends come from modules/common, already listed
    # with the NixOS options.
  in
    lib.filterAttrs (name: _: !(nixosYomi ? ${name})) all;

  relative = file: let
    m = builtins.match "/nix/store/[^/]+-source/(.*)" (toString file);
  in
    if m == null
    then toString file
    else builtins.head m;
  render = options:
    (pkgs.nixosOptionsDoc {
      options = {yomi = options;};
      warningsAreErrors = false;
      transformOptions = opt:
        opt
        # A default derived from a sibling option, such as a port taken from
        # yomi.ports.<name>, has no value outside a real entry.
        // lib.optionalAttrs (opt ? default) {
          default = let
            r = builtins.tryEval (builtins.deepSeq opt.default opt.default);
          in
            if r.success
            then r.value
            else {
              _type = "literalMD";
              text = "derived from the other settings of the entry";
            };
        }
        // {
          declarations = map (d: {
            name = relative d;
            url = "../${relative d}";
          }) (lib.filter (d: lib.hasPrefix "/nix/store" (toString d)) opt.declarations);
        };
    })
    .optionsCommonMark;
in
  # Store paths change with every nixpkgs update, which would leave this file
  # stale on each automatic input bump, so they are written as <store path>.
  pkgs.runCommand "yomi-options.md" {} ''
    {
      echo '# yomi options'
      echo
      echo 'Generated from the modules by `just docs`; do not edit by hand.'
      echo 'NixOS options first, then the ones only Home Manager has.'
      echo
      echo '# NixOS'
      echo
      cat ${render nixosYomi}
      echo
      echo '# Home Manager'
      echo
      cat ${render homeYomi}
    } | sed -E 's#/nix/store/[a-z0-9]{32}-[^"/ )]*#<store path>#g' | cat -s > $out
  ''
