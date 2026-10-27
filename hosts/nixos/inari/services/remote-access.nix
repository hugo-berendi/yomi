{config, ...}: {
  # Browser access from the work laptop; see modules/nixos/remote-access.nix.
  #
  # Off until a human has created the Pocket ID client and added
  # remote_access_client_id, remote_access_client_secret and
  # remote_access_cookie_secret to ../secrets.yaml: sops-nix fails activation
  # on a missing key, so enabling it first would break the next switch.
  yomi.remoteAccess = {
    enable = false;
    sopsFile = ../secrets.yaml;
    issuerUrl = config.yomi.cloudflared.at.pocket-id.url;
    # lab is Homepage, code is opencode. Home Assistant (home) is deliberately
    # not listed.
    endpoints = ["lab" "grafana" "status" "t3code" "n8n" "code"];
  };
}
