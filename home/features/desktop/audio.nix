{pkgs, ...}: {
  home.packages = [pkgs.pwvucontrol];
  # Makes bluetooth media controls work
  services.mpris-proxy.enable = true;
}
