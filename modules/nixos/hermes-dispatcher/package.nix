{
  pkgs,
  upstream,
}:
upstream.overridePythonAttrs (old: {
  postPatch =
    (old.postPatch or "")
    + ''
      ${pkgs.python3}/bin/python3 ${./patch-runtime.py} .
      cp ${./ciel_routing.py} agent/ciel_routing.py
      cp ${./ciel_watch.py} agent/ciel_watch.py
      cp ${./broker_client.py} agent/ciel_broker_client.py
    '';
  pythonImportsCheck = (old.pythonImportsCheck or []) ++ ["agent.ciel_routing"];
  postInstall = let
    original = old.postInstall or "";
    sourceCopy = "cp -r ${builtins.unsafeDiscardStringContext (toString old.src)}/plugins ";
  in
    assert builtins.length (pkgs.lib.splitString sourceCopy original) == 2;
      builtins.replaceStrings [sourceCopy] ["cp -r plugins "] original;
  postInstallCheck =
    (old.postInstallCheck or "")
    + ''
      cmp agent/ciel_routing.py "$out"/lib/python*/site-packages/agent/ciel_routing.py
      cmp gateway/session_execution.py "$out"/lib/python*/site-packages/gateway/session_execution.py
      cmp gateway/run_turn_runner.py "$out"/lib/python*/site-packages/gateway/run_turn_runner.py
      cmp plugins/platforms/matrix/adapter.py "$out/share/hermes/plugins/platforms/matrix/adapter.py"
      CIEL_HERMES_SOURCE="$PWD" ${pkgs.python3}/bin/python3 ${./test_cache_lifecycle.py}
    '';
})
