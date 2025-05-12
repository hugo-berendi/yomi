rebuild:
   sudo nixos-rebuild switch --flake .#$(hostname) --show-trace --fast --accept-flake-config
