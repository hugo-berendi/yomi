# Keymap order is the import order, so each file holds a run of the old
# per-topic files in their original sequence.
{
  imports = [
    ./basics.nix
    ./navigation.nix
    ./snacks.nix
    ./tools.nix
    ./editing.nix
  ];
}
