let
  pkgs = import <nixpkgs> {};
in
  pkgs.mkShell {
    packages = [
      (pkgs.python3.withPackages (python-pkgs: [
        python-pkgs.pyquery
        python-pkgs.requests
        python-pkgs.pydexcom
      ]))
    ];
  }
