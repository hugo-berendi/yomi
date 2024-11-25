{config, ...}: {
  yomi.nginx.at.ntfy.port = config.yomi.ports.ntfy;
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://ntfy.hugo-berendi.de";
      listen-http = ":${builtins.toString config.yomi.ports.ntfy}";
    };
  };
}
