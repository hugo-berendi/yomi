# Shells for working on this repository. Project shells belong in the
# projects' own flakes.
args: rec {
  bootstrap = import ./bootstrap/shell.nix args;
  yomi = import ./yomi.nix args;
  default = yomi;
}
