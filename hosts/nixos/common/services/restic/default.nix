{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.restic;
  home = config.users.users.${config.yomi.pilot.name}.home;
  localSet = paths: pruneOpts: exclude: {
    inherit paths pruneOpts;
    initialize = true;
    checkOpts = ["--with-cache" "--read-data-subset=5%"];
    exclude = [".direnv" ".git" ".stfolder" ".stversions"] ++ exclude;
  };
in {
  yomi.restic.sopsFile = ../../secrets.yaml;
  yomi.restic.sets = lib.mkIf cfg.enable {
    data = localSet ["/persist/data"] ["--keep-daily 7" "--keep-weekly 4" "--keep-monthly 12" "--keep-yearly 0"] ["/persist/data${home}/projects"];
    state = localSet ["/persist/state"] ["--keep-daily 3" "--keep-weekly 1" "--keep-monthly 1" "--keep-yearly 0"] ["/persist/state/${home}/discord" "/persist/state/${home}/steam"];
  };
}
