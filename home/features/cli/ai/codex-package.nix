# codex from llm-agents, bumped ahead of it. Drop the override once
# https://github.com/numtide/llm-agents.nix/pull/10062 (0.158.0 -> 0.159.1)
# lands; the hashes are taken from that PR.
{
  inputs,
  pkgs,
}:
inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex.override {
  version = "0.159.1";
  hash = "sha256-74sN8GM4W+u8bMxOenSp9tmIDqAtrABCmU5J8IsqZWA=";
  cargoVendor.cargoHash = "sha256-3X4gmzAZG10DDcI667k9Zf+r3IvzeAAWD1NbTdQZyGY=";
}
