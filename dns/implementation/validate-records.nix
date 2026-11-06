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
      && (!(lib.elem "CNAME" types) || builtins.length entries == 1)
      # ALIAS is a root CNAME at Cloudflare, so it cannot sit next to address
      # records, but it can next to MX and TXT.
      && (!(lib.elem "ALIAS" types) || !(lib.any (t: lib.elem t ["A" "AAAA" "CNAME"]) types));
    message = "DNS ${name} has conflicting records: combine values of the same type into one record, do not mix CNAME with other types, and do not mix ALIAS with A, AAAA or CNAME.";
  })
  groups
