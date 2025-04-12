{
  pkgs,
  octodnsConfig,
  nixosConfigurations ? {},
  extraModules ? [],
}: let
  #  {{{ Prepare packages
  octodns = pkgs.python3Packages.callPackage (import ./octodns.nix) {};
  # octodns = pkgs.octodns.overrideAttrs (_: {
  #   version = "unstable-2024-10-08";
  #   src = pkgs.fetchFromGitHub {
  #     owner = "octodns";
  #     repo = "octodns";
  #     rev = "a1456cb1fcf00916ca06b204755834210a3ea9cf";
  #     sha256 = "192hbxhb0ghcbzqy3h8q194n4iy7bqfj9ra9qqjff3x2z223czxb";
  #   };
  # });

  octodns-cloudflare = pkgs.python312Packages.callPackage (import ./octodns-cloudflare.nix) {
    inherit octodns;
  };

  fullOctodns = octodns.withProviders (ps: [octodns-cloudflare]);
  # fullOctodns = octodns.withProviders (ps: [pkgs.octodns-providers.cloudflare]);
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
      ];

      postBuild = ''
        sed '/^providers:/,/^[^ ]/ s|^\( *zones:\)$|\1\n  directory: "${octodns-zones}"|' ${octodnsConfig} > $out/config.yaml

        wrapProgram $out/bin/octodns-sync \
          --run 'export CLOUDFLARE_TOKEN=$( \
            sops \
              --decrypt \
              --extract "[\"cloudflare_dns_api_token\"]" \
              ./hosts/nixos/common/secrets.yaml \
          )'
      '';
    };
    #  }}}
<<<<<<< Updated upstream
<<<<<<< HEAD
    octodns-full = fullOctodns;
=======
    octodns-full = octodns;
>>>>>>> 66600b6 (try fixing octodns)
=======
    octodns-pkg = fullOctodns;
>>>>>>> Stashed changes
  }
