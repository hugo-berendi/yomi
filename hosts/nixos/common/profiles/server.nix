# The home server (inari): the shared fleet settings plus OCI containers,
# nixarr's media stack options, ACME and the local restic sets.
{inputs, ...}: {
  # {{{ Imports
  # Modules are collected breadth-first, and list options (systemPackages,
  # tmpfiles rules, persistence directories) merge in that order. The two
  # wrappers keep nixarr, oci and restic at the depth and position they had
  # beside ./fleet.nix's imports, so inari's units and lists stay as they were.
  imports = [
    ../base.nix
    {imports = [inputs.nixarr.nixosModules.default];}
    ./fleet.nix
    {
      imports = [
        ../services/oci.nix
        ../services/restic.nix
      ];
    }
  ];
  # }}}

  yomi.acme = {
    sopsFile = ../secrets.yaml;
    email = "acme@hugo-berendi.de";
  };
}
