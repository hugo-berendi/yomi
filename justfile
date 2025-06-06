rebuild:
   sudo nixos-rebuild switch --flake .#$(hostname) --show-trace --fast --accept-flake-config
dns:
  nix shell .#packages."x86_64-linux".octodns-sync --command octodns-sync --doit
