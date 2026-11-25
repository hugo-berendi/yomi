# Whether inari's secrets.yaml has a key, decided at evaluation time.
#
# sops-install-secrets validates its manifest when the system is built, so
# naming a key that does not exist in secrets.yaml fails the entire
# nixos-rebuild, not just the service that wanted it: the host cannot apply
# any configuration until somebody with the age key is at a keyboard. Key
# names in a sops file are plaintext (only the values are encrypted), so a
# service can wire an optional secret the moment it is added and run without
# it until then. A service that runs differently without its secret says so
# in `warnings`.
#
# The key has to start a line: sops-nix reads top-level keys, and "token"
# must not match "n8n_ntfy_token:".
let
  secrets = builtins.readFile ../secrets.yaml;
in
  key: builtins.match "(.*\n)?${key}:.*" secrets != null
