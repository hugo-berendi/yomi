{
  pkgs,
  upstream,
}:
upstream.overridePythonAttrs (old: {
  postPatch =
    (old.postPatch or "")
    + ''
      ${pkgs.python3}/bin/python3 ${./patch-hermes.py} .
      cp ${./signal_unix.py} plugins/platforms/signal/signal_unix.py
    '';
  # Upstream copies bundled plugins from src rather than the patched tree.
  # Patch both locations so plugin discovery cannot restore the HTTP client.
  postInstall =
    (old.postInstall or "")
    + ''
      cp plugins/platforms/signal/{adapter,signal_unix}.py \
        $out/share/hermes/plugins/platforms/signal/
    '';
})
