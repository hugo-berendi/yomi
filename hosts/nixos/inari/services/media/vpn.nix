{config, ...}: {
  sops.secrets.wireguard_conf.sopsFile = ../../secrets.yaml;
  nixarr.vpn = {
    enable = true;
    wgConf = config.sops.secrets.wireguard_conf.path;
  };
}
