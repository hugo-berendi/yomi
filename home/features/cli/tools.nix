{pkgs, ...}: {
  home.packages = with pkgs; [
    aria2
    most
    procs
    rm-improved
    rsync
    sd
    gping
    speedtest-cli
    dogdns
  ];

  home.shellAliases = {
    wget = "aria2c";
    less = "most";
    ps = "procs";
    rm = "rip";
    sd = "sed";
  };
}
