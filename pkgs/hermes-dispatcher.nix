# Flake-level entry for the Hermes dispatcher app, so it and its tests
# (passthru.tests) evaluate without a host. The NixOS module builds the same
# app from the same file; see modules/nixos/hermes-dispatcher/app.nix.
{
  pkgs,
  inputs,
}:
import ../modules/nixos/hermes-dispatcher/app.nix {
  inherit pkgs;
  inherit (pkgs) lib;
  hermesAgent = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hermes-agent;
  skillsSource = inputs.skills;
}
