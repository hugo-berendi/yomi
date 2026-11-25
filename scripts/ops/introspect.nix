# Read-only questions about an evaluated host, answered from the module
# system's own record of where each definition came from. Used by
# scripts/ops/introspect.py (`just where`, `just explain`).
{lib}: let
  # Definitions carry the flake source store path; show repo paths instead.
  relative = file: let
    m = builtins.match "/nix/store/[^/]+-source/(.*)" (toString file);
  in
    if m == null
    then toString file
    else builtins.head m;

  # A raw definition may still be wrapped in mkIf, mkMerge, mkDefault, ...
  unwrap = v:
    if builtins.isAttrs v && v ? _type
    then
      if v._type == "if"
      then lib.optionals v.condition (unwrap v.content)
      else if v._type == "merge"
      then lib.concatMap unwrap v.contents
      else if v._type == "override" || v._type == "order"
      then unwrap v.content
      else [v]
    else [v];

  # Something JSON can carry: derivations, paths and functions become names.
  plain = depth: v:
    if lib.isDerivation v
    then "<derivation ${v.name or "?"}>"
    else if builtins.isFunction v
    then "<function>"
    else if builtins.isPath v
    then relative v
    else if builtins.isAttrs v
    then
      if depth == 0
      then "<attrs>"
      else lib.mapAttrs (_: plain (depth - 1)) (builtins.removeAttrs v ["_module"])
    else if builtins.isList v
    then map (plain (depth - 1)) v
    else v;

  # The option a path starts with, and the attribute path left below it.
  findOption = options: path: let
    go = prefix: rest: node:
      if lib.isOption node
      then {
        inherit prefix rest;
        option = node;
      }
      else if rest == [] || !(builtins.isAttrs node) || !(node ? ${builtins.head rest})
      then null
      else go (prefix ++ [(builtins.head rest)]) (builtins.tail rest) node.${builtins.head rest};
  in
    go [] path options;

  # The definitions of `path`, even below an attribute-set option:
  # [{file, value}] with each value already taken at the full path.
  definitionsAt = options: path: let
    found = findOption options path;
    pick = v:
      if found.rest == []
      then [v]
      else lib.optional (builtins.isAttrs v && lib.hasAttrByPath found.rest v) (lib.getAttrFromPath found.rest v);
  in
    if found == null
    then []
    else
      lib.concatMap (d:
        map (value: {
          file = relative d.file;
          inherit value;
        }) (lib.concatMap pick (unwrap d.value)))
      found.option.definitionsWithLocations;
in {
  # Every file that defines `path`, and what it sets there.
  where = {
    options,
    path,
  }: let
    found = findOption options path;
  in
    if found == null
    then throw "no option at ${lib.concatStringsSep "." path}"
    else {
      option = lib.concatStringsSep "." found.prefix;
      declared = map relative found.option.declarations;
      definitions = map (d: d // {value = plain 3 d.value;}) (definitionsAt options path);
    };

  # What the files under `dir` contribute to a host: ports, endpoints,
  # reachability, units, containers, secrets, state and backups.
  explain = {
    config,
    options,
    dir,
  }: let
    # A directory imported as a module is recorded under its own path.
    inDir = file: file == lib.removeSuffix "/" dir || lib.hasPrefix dir file;
    defsIn = path: lib.filter (d: inDir d.file) (definitionsAt options path);
    namesIn = path:
      lib.unique (lib.concatMap (d:
        lib.concatMap (v:
          if builtins.isAttrs v
          then builtins.attrNames v
          else []) (unwrap d.value)) (defsIn path));
    valuesIn = path: lib.concatMap (d: lib.concatMap lib.toList (unwrap d.value)) (defsIn path);
    files = lib.unique (map (d: d.file) (lib.concatMap defsIn [
      ["yomi" "ports"]
      ["yomi" "web" "at"]
      ["systemd" "services"]
      ["sops" "secrets"]
    ]));
    get = path: f: lib.genAttrs (namesIn path) (n: f (lib.getAttrFromPath path config).${n});
  in {
    inherit files;
    ports = get ["yomi" "ports"] (p: p);
    web = get ["yomi" "web" "at"] (e: {
      inherit (e) url transport authentication;
      monitor = e.monitor.enable;
      homepage =
        if (e.homepage or null) == null
        then null
        else "${e.homepage.group}/${e.homepage.name}";
    });
    staticWeb = get ["yomi" "nginx" "at"] (e: e.url);
    lan = get ["yomi" "network" "exposure"] (g: {inherit (g) port protocols interface;});
    private = get ["yomi" "expose" "private"] (r: {inherit (r) mode alias destination tcpPorts udpPorts users roles;});
    rawTcp = get ["yomi" "expose" "tcp"] (r: {inherit (r) port publicPort;});
    rawUdp = get ["yomi" "expose" "udp"] (r: {inherit (r) port publicPort;});
    units = namesIn ["systemd" "services"];
    timers = namesIn ["systemd" "timers"];
    containers = get ["virtualisation" "oci-containers" "containers"] (c: c.image);
    secrets = namesIn ["sops" "secrets"] ++ map (n: "template:${n}") (namesIn ["sops" "templates"]);
    state = get ["yomi" "persistence" "at" "state" "apps"] (a: map (d: d.directory or d) a.directories);
    cache = get ["yomi" "persistence" "at" "cache" "apps"] (a: map (d: d.directory or d) a.directories);
    offsite = valuesIn ["yomi" "restic" "offsite" "paths"];
  };
}
