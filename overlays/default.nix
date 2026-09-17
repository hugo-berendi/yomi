# This file defines overlays
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {pkgs = final;};

  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays

  modifications = _final: prev: {
    python313 = prev.python313.override {
      packageOverrides = _pyfinal: pyprev: {
        pyrate-limiter = pyprev.pyrate-limiter.overridePythonAttrs (_old: {
          doCheck = false;
        });
      };
    };

    # nixpkgs' committed pnpmDeps hash for n8n 2.37.10 doesn't match what
    # actually gets fetched; pin the observed-correct hash until upstream
    # regenerates it.
    n8n = prev.n8n.overrideAttrs (old: {
      pnpmDeps = old.pnpmDeps.override {
        hash = "sha256-MXRUSvyYymI5uDB33W4Dwt5FcCW+3uCLmNrWuXY0zDM=";
      };
    });
  };
}
