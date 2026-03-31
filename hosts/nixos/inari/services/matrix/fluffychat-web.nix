{pkgs, ...}: {
  yomi.nginx.at.fluffychat = {
    files = pkgs.fluffychat-web;
    subdomain = "fluffy";
  };
}
