# Configuration pieces included on all (nixos) hosts
{
  inputs,
  lib,
  config,
  outputs,
  ...
}: {
  services.protonvpn = {
    enable = true;
    autostart = true;
    interface = {
      name = "wg0";
      ip = "10.2.0.2/32";
      privateKeyFile = "/persist/data/secrets/protonvpn";
      dns = {
        enable = true;
        ip = "10.2.0.1";
      };
    };
    endpoint = {
      publicKey = "jA3Pf5MWpHk8STrLXVPyM28aV3yAZgw9nEGoIFAyxiI=";
      ip = "185.177.124.190";
      port = 51820;
    };
  };
}
