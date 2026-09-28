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
  };
}
