{
  config,
  lib,
  ...
}:
lib.mkIf config.yomi.t3codeVm.enable {
  systemd.network.netdevs."25-t3test" = {
    netdevConfig = {
      Name = "t3test0";
      Kind = "tap";
    };
    tapConfig = {
      User = "t3code-vm";
      Group = "t3code-vm";
    };
  };
  systemd.network.networks."25-t3test" = {
    matchConfig.Name = "t3test0";
    address = ["10.231.0.1/30"];
    networkConfig = {
      LinkLocalAddressing = "no";
      IPv6AcceptRA = false;
      ConfigureWithoutCarrier = true;
    };
    linkConfig.RequiredForOnline = "no";
  };
  systemd.services.t3code-vm = {
    requires = ["systemd-networkd.service" "sys-subsystem-net-devices-t3test0.device"];
    after = ["systemd-networkd.service" "nftables.service" "sys-subsystem-net-devices-t3test0.device"];
    serviceConfig.SupplementaryGroups = ["kvm"];
    serviceConfig.MemoryMax = "8G";
    serviceConfig.IOWeight = 10;
    unitConfig.StartLimitIntervalSec = 300;
    unitConfig.StartLimitBurst = 3;
  };
  yomi.persistence.at.state.apps.t3code-vm.directories = [
    {
      directory = "/var/lib/t3code-vm";
      user = "t3code-vm";
      group = "t3code-vm";
      mode = "0700";
    }
  ];
}
