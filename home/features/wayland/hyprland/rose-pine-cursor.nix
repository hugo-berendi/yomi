{pkgs}:
pkgs.stdenv.mkDerivation {
  pname = "rose-pine-cursor";
  version = "1.0";

  src = pkgs.fetchFromGitHub {
    owner = "ndom91";
    repo = "rose-pine-hyprcursor";
    rev = "v0.3.2";
    sha256 = "0iaplhyyh7qczp037cfs8y1clbaz662cz1qsf4m7a0bam7k1gd82";
  };

  installPhase = ''
    mkdir -p $out/share/icons
    cp -r * $out/share/icons/
  '';

  # meta = with pkgs.stdenv.lib; {
  #   description = "Rose Pine cursor theme for Hyprland";
  #   license = licenses.mit;
  #   platforms = platforms.linux;
  # };
}
