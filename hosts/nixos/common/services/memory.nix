{lib, ...}: {
  # {{{ zram - Compressed RAM swap
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  # }}}

  # {{{ systemd-oomd - Out of Memory Daemon
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
    enableSystemSlice = true;
  };
  # }}}

  # {{{ Kernel memory tuning
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkDefault 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
    "vm.page-cluster" = 0;
  };
  # }}}
}
