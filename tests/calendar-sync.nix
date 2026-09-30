{
  pkgs,
  package,
}: let
  python = pkgs.python3.withPackages (_: package.propagatedBuildInputs);
in
  pkgs.runCommand "yomi-calendar-sync-checks" {nativeBuildInputs = [python];} ''
    python3 ${./calendar-sync.py} ${package}/${pkgs.python3.sitePackages}
    echo 'Google recurrence updates preserve source items and DAV preconditions' > "$out"
  ''
