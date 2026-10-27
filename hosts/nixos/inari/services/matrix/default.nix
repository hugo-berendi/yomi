{
  pkgs,
  upkgs,
  ...
}: {
  imports = [
    ./tuwunel.nix
    ./bridges.nix
    ./sable.nix
  ];

  yomi.nginx.at.element.files = upkgs.element-web;
  yomi.nginx.at.fluffychat = {
    files = pkgs.fluffychat-web;
    subdomain = "fluffy";
  };
}
