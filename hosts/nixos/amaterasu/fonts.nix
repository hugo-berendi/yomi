{ stdenvNoCC, fetchzip, pkgs }:

stdenvNoCC.mkDerivation rec {
          pname = "maple-font";
          dontConfigue = true;
	  dontBuild = true;
	  version = "6.4";

          src = fetchzip {
            url =
              "https://github.com/subframe7536/maple-font/releases/download/v${version}/MapleMono-NF.zip";
            sha256 = "sha256-NoLccQLNuHGyUS1gZIDXMbDRJSyQ3tHZZLTTH4fZVHI=";
            stripRoot = false;
          };

          installPhase = ''
            mkdir -p $out/share/fonts
            cp -R $src $out/share/fonts/maple-nf/
          '';

          meta = {
            description =
              "Open source monospace & nerd font with round corner and ligatures.";
          };
        }
