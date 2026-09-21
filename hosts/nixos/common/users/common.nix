{
  authorizedKeys = {
    outputs,
    lib,
  }: let
    # Record containing all the hosts
    hosts = outputs.nixosConfigurations;

    # Every id_*.pub in a host's keys/ dir -- lets a host list more than one
    # login key (e.g. a resident FIDO2 credential alongside a plain key
    # during rollover) without touching this file again. ssh_host_*.pub in
    # the same directory is the host key, not a login key, and is excluded
    # by the "id_" prefix.
    loginKeys = host: let
      dir = ../../${host}/keys;
    in
      if builtins.pathExists dir
      then
        lib.pipe (builtins.readDir dir) [
          builtins.attrNames
          (builtins.filter (name: lib.hasPrefix "id_" name && lib.hasSuffix ".pub" name))
          (map (name: dir + "/${name}"))
        ]
      else [];
  in
    lib.pipe hosts [
      # attrsetof host -> attrsetof path[]
      (builtins.mapAttrs
        (name: _: loginKeys name)) # string -> host -> path[]

      # attrsetof path[] -> path[][]
      builtins.attrValues

      # path[][] -> path[]
      lib.flatten
    ];
}
