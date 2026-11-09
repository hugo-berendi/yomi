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
  # Copy the patched tree once. Copying src first preserves store permissions
  # (0555/0444), so a later overlay cannot create or overwrite plugin files.
  postInstall = let
    original = old.postInstall or "";
    sourceCopy = "cp -r ${builtins.unsafeDiscardStringContext (toString old.src)}/plugins ";
  in
    assert builtins.length (pkgs.lib.splitString sourceCopy original) == 2;
      builtins.replaceStrings [sourceCopy] ["cp -r plugins "] original;

  pythonImportsCheck = (old.pythonImportsCheck or []) ++ ["plugins.platforms.signal.adapter"];
  postInstallCheck =
    (old.postInstallCheck or "")
    + ''
      cmp plugins/platforms/signal/adapter.py $out/share/hermes/plugins/platforms/signal/adapter.py
      cmp plugins/platforms/signal/signal_unix.py $out/share/hermes/plugins/platforms/signal/signal_unix.py
    '';
})
