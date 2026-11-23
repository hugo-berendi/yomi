# Every module in a directory, for `imports`: each `*.nix` file and each
# subdirectory that has a default.nix. Names starting with `_` are skipped, so
# a helper that is not a module can live beside the modules as `_name.nix`.
#
# Adding a service is then one new file; nobody edits an import list.
dir: let
  entries = builtins.readDir dir;
  isModule = name: let
    type = entries.${name};
  in
    builtins.match "_.*" name
    == null
    && (
      if type == "directory"
      then builtins.pathExists (dir + "/${name}/default.nix")
      else builtins.match ".*\\.nix" name != null && name != "default.nix"
    );
in
  map (name: dir + "/${name}") (builtins.filter isModule (builtins.attrNames entries))
