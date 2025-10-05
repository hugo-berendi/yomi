{
  lib,
  inputs,
  config,
  ...
}: {
  imports = [inputs.impermanence.nixosModules.impermanence];

  # {{{ Base persistence
  environment.persistence."/persist/state".directories = [
    "/var/lib/systemd"
    "/var/lib/nixos"
    "/var/log"
  ];
  # }}}
  # {{{ FUSE
  programs.fuse.userAllowOther = true;
  # }}}
  # {{{ Create home directories
  systemd.tmpfiles.rules = let
    users = lib.filter (v: v != null && v.isNormalUser) (
      lib.mapAttrsToList (_: u: u) config.users.users
    );

    mkHomePersistFor = location:
      lib.forEach users (user: "d ${location}${user.home} ${user.homeMode} ${user.name} ${user.group} -");
  in
    lib.flatten [
      (mkHomePersistFor "/persist/data")
      (mkHomePersistFor "/persist/state")
      (mkHomePersistFor "/persist/local/cache")
    ];
  # }}}
}
