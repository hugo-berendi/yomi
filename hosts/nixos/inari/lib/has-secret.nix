# Whether inari's secrets.yaml has a key, decided at evaluation time.
#
# sops-install-secrets validates its manifest when the system is built, so
# naming a key that does not exist in secrets.yaml fails the entire
# nixos-rebuild, not just the service that wanted it: the host cannot apply
# any configuration until somebody with the age key is at a keyboard. Key
# names in a sops file are plaintext (only the values are encrypted), so a
# service can wire an optional secret the moment it is added and run without
# it until then.
let
  secrets = builtins.readFile ../secrets.yaml;
in
  key: builtins.match ".*[[:space:]]*${key}:.*" secrets != null
