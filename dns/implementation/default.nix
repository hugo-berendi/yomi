{
  pkgs,
  octodnsConfig,
  nixosConfigurations ? {},
  extraModules ? [],
}: let
  #  {{{ Prepare packages
  octodns = pkgs.octodns.overrideAttrs (_: {
    version = "unstable-2024-10-13";
    src = pkgs.fetchFromGitHub {
      owner = "octodns";
      repo = "octodns";
      rev = "e30d91783eb0b85507605eb51fcfb75b0773fb26";
      sha256 = "Yl7266I8aH9cEsu+/6yYn6TJPKsmhHotC3y+/cYpK3M=";
    };
  });

  octodns-cloudflare = pkgs.pythonPackages.callPackage (import ./octodns-cloudflare.nix) {
    inherit octodns;
  };

  fullOctodns = octodns.withProviders (ps: [octodns-cloudflare]);
in
  #  }}}
  rec {
    #  {{{ Build zone files
    octodns-zones = let
      nixosConfigModules =
        pkgs.lib.mapAttrsToList (_: current: {
          yomi.dns = current.config.yomi.dns;
        })
        nixosConfigurations;

      evaluated = pkgs.lib.evalModules {
        specialArgs = {
          inherit pkgs;
        };

        modules = [./nixos-module.nix] ++ nixosConfigModules ++ extraModules;
      };
    in
      import ./gen-zone-file.nix {
        inherit pkgs;
        inherit (evaluated) config;
      };
    #  }}}
    #  {{{ Make the CLI use the newly built zone files
    octodns-sync = pkgs.symlinkJoin {
      name = "octodns-sync";
      paths = [fullOctodns];
      buildInputs = [
        pkgs.makeWrapper
        pkgs.yq
      ];

      postBuild = ''
        cat ${octodnsConfig} | yq '.providers.zones.directory="${octodns-zones}"' > $out/config.yaml
        wrapProgram $out/bin/octodns-sync \
          --run 'export CLOUDFLARE_TOKEN=$( \
              sops \
                --decrypt \
                --extract "[\"cloudflare_dns_api_token\"]" \
                ./hosts/nixos/common/secrets.yaml \
            ) && export CLOUDFLARE_EMAIL=hugo.berendi@proton.me' \
          --add-flags "--config-file $out/config.yaml"
      '';
    };
    #  }}}
  }
