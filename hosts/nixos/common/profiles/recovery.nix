# The installer and recovery ISO: the shared fleet settings so the pilot's
# keys, shell and theme match the machines it restores, and nothing that
# needs a desktop, containers or a backup repository.
{
  imports = [
    ../base.nix
    ./fleet.nix
  ];
}
