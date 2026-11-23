# The diabetes app itself: Python sources, templates, static assets and unit
# tests, with no host, port, secret or persistence settings. default.nix in
# this directory is the deployment and consumes `python` and `src` from here,
# so this file can move to the app's own repository without the service
# changing. Evaluate it alone with `callPackage ./package.nix {}`.
{
  lib,
  python3,
  runCommand,
  makeWrapper,
}: let
  python = python3.withPackages (p: [p.flask p.waitress p.pydexcom p.matplotlib p.playwright]);
  src = builtins.path {
    path = ./.;
    # The Nix files and the README live beside the sources; keep them out so
    # the store path (and every unit embedding it) does not change when one
    # of them is edited.
    filter = path: _:
      !(builtins.elem (baseNameOf path) ["default.nix" "package.nix" "README.md"]);
    name = "yomi-diabetes";
  };
  tests = runCommand "yomi-diabetes-tests" {} ''
    export MPLCONFIGDIR="$TMPDIR/matplotlib"
    export PYTHONDONTWRITEBYTECODE=1
    ${python}/bin/python -m unittest discover -s ${src} -v
    touch "$out"
  '';
in
  runCommand "yomi-diabetes-app" {
    nativeBuildInputs = [makeWrapper];
    passthru = {
      inherit python src;
      tests.unit = tests;
    };
    meta = {
      description = "Private diabetes journal and report generator";
      mainProgram = "yomi-diabetes";
      platforms = lib.platforms.linux;
    };
  } ''
    makeWrapper ${python}/bin/python $out/bin/yomi-diabetes --add-flags ${src}/app.py
  ''
