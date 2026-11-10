# The router's real client against the pinned Hermes webhook adapter, with the
# routes the inari configuration generates. See tests/hermes_alert_webhook.py.
{
  pkgs,
  configuration,
}: let
  launcher = configuration.config.yomi.hermesDispatcher.package;
  inherit (launcher.passthru) hermes launchSettings;
  n8n = ../hosts/nixos/inari/services/n8n;
in
  pkgs.runCommand "hermes-alert-webhook" {nativeBuildInputs = [pkgs.nodejs];} ''
    export HOME=$TMPDIR
    # The interpreter Hermes itself runs on, taken from its own wrapper.
    python=$(head -1 ${hermes}/bin/.hermes-wrapped | cut -c3-)
    "$python" ${./hermes_alert_webhook.py} \
      ${hermes}/bin/.hermes-wrapped ${launchSettings} ${../modules/nixos/hermes-dispatcher} \
      ${pkgs.nodejs}/bin/node ${./hermes-alert-client.cjs} ${n8n}/alert-triage.cjs ${n8n}/alert-router.cjs
    touch "$out"
  ''
