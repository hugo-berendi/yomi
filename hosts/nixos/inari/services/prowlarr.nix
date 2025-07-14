{...}: {
  services = {
    prowlarr = {
      enable = true;
    };
  };

  # This is the default port, and can only be changed via the GUI
  yomi.nginx.at.prowlarr.port = 9696;

  systemd.tmpfiles.rules = ["z /var/lib/private 0700 root"];

  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/private";
      mode = "0700";
    }
  ];
}
