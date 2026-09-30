{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.restic;
  excludes = lib.concatMap (user: user.yomi.persistence.localBackupExcludes) (lib.attrValues (config.home-manager.users or {}));
  excludesFor = root: lib.filter (path: lib.hasPrefix "${root}/" path) excludes;
  localSet = paths: pruneOpts: exclude: {
    inherit paths pruneOpts;
    initialize = true;
    checkOpts = ["--with-cache" "--read-data-subset=5%"];
    exclude = [".direnv" ".git" ".stfolder" ".stversions"] ++ exclude;
  };
in {
  yomi.restic.sopsFile = ../../secrets.yaml;
  yomi.restic.sets = lib.mkIf cfg.enable {
    data = localSet ["/persist/data"] ["--keep-daily 7" "--keep-weekly 4" "--keep-monthly 12" "--keep-yearly 0"] (excludesFor "/persist/data");
    state = localSet ["/persist/state"] ["--keep-daily 3" "--keep-weekly 1" "--keep-monthly 1" "--keep-yearly 0"] (excludesFor "/persist/state");
  };
}
