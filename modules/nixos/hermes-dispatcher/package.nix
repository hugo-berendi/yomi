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
      cp ${./runtime_approvals.py} agent/runtime_approvals.py
      cp ${./ciel_webhook_policy.py} agent/ciel_webhook_policy.py
      cp ${./broker_client.py} agent/ciel_broker_client.py
      cp ${./ciel_voice.py} agent/ciel_voice.py
      cp ${./ciel_voice_tts.py} agent/ciel_voice_tts.py
    '';
  pythonImportsCheck = (old.pythonImportsCheck or []) ++ ["agent.ciel_routing" "agent.ciel_voice" "agent.ciel_voice_tts" "agent.ciel_webhook_policy"];
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
      cmp agent/runtime_approvals.py "$out"/lib/python*/site-packages/agent/runtime_approvals.py
      cmp agent/transports/codex_app_server.py "$out"/lib/python*/site-packages/agent/transports/codex_app_server.py
      cmp agent/transports/codex_app_server_session.py "$out"/lib/python*/site-packages/agent/transports/codex_app_server_session.py
      cmp gateway/session_execution.py "$out"/lib/python*/site-packages/gateway/session_execution.py
      cmp gateway/run_turn_runner.py "$out"/lib/python*/site-packages/gateway/run_turn_runner.py
      cmp gateway/stream_consumer.py "$out"/lib/python*/site-packages/gateway/stream_consumer.py
      cmp agent/codex_runtime.py "$out"/lib/python*/site-packages/agent/codex_runtime.py
      cmp plugins/platforms/matrix/adapter.py "$out/share/hermes/plugins/platforms/matrix/adapter.py"
      CIEL_HERMES_SOURCE="$PWD" ${pkgs.python3}/bin/python3 ${./test_cache_lifecycle.py}
      cp ${./runtime_approvals.py} runtime_approvals.py
      cp ${./ciel_watch.py} ciel_watch.py
      cp ${./broker_client.py} broker_client.py
      cp ${./test_runtime_approvals.py} test_runtime_approvals.py
      CIEL_HERMES_SOURCE="$PWD" ${pkgs.python3}/bin/python3 test_runtime_approvals.py
    '';
})
