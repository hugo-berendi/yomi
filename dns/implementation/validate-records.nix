{
  lib,
  records,
}: let
  groups = lib.groupBy (r: "${r.at}.${r.zone}") (lib.unique records);
in
  lib.mapAttrsToList (name: entries: {
    assertion = let
      types = map (r: r.type) entries;
    in
      builtins.length types
      == builtins.length (lib.unique types)
      && (!(lib.elem "CNAME" types) || builtins.length entries == 1);
    message = "DNS ${name} has conflicting records: combine values of the same type into one record, and do not mix CNAME with other types.";
  })
  groups
