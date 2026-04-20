{
  pkgs,
  octodnsConfig,
  nixosConfigurations ? {},
  extraModules ? [],
}: let
  #  {{{ Prepare packages
  fullOctodns = pkgs.octodns.withProviders (ps: [pkgs.octodns-providers.cloudflare pkgs.octodns-providers.ddns]);
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
        pkgs.yq
      ];

      postBuild = ''
        cat ${octodnsConfig} | yq '.providers.zones.directory="${octodns-zones}"' > $out/config.base.yaml

        rm -f $out/bin/octodns-sync

        cat > $out/bin/octodns-sync <<'EOF'
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        cloudflare_token="$(${pkgs.sops}/bin/sops --decrypt --extract '["cloudflare_dns_api_token"]' ./hosts/nixos/common/secrets.yaml)" || {
          echo "failed to decrypt cloudflare_dns_api_token via sops" >&2
          exit 1
        }

        if [ -z "$cloudflare_token" ] || [ "$cloudflare_token" = "null" ]; then
          echo "cloudflare_dns_api_token is empty" >&2
          exit 1
        fi

        export CLOUDFLARE_TOKEN="$cloudflare_token"

        zones_dir="${octodns-zones}"
        dkim_public_key="$(${pkgs.sops}/bin/sops --decrypt --extract '["simplelogin_dkim_public_key"]' ./hosts/nixos/inari/secrets.yaml 2>/dev/null || true)"

        if [ -n "''${dkim_public_key}" ]; then
          zones_dir="$(mktemp -d)"
          cp -R "${octodns-zones}/." "$zones_dir/"
          export SIMPLELOGIN_DKIM_VALUE="v=DKIM1\\; k=rsa\\; p=''${dkim_public_key}"
          ${pkgs.yq}/bin/yq -y -i '(.yokai[] | select(.type == "TXT" and .value == "v=DKIM1\\; k=rsa\\; p=__SIMPLELOGIN_DKIM_PUBLIC_KEY__") | .value) = strenv(SIMPLELOGIN_DKIM_VALUE)' "$zones_dir/hugo-berendi.de.yaml"
        fi

        config_file="$(mktemp)"
        package_root="$(dirname "$(dirname "$(readlink -f "$0")")")"
        cp "$package_root/config.base.yaml" "$config_file"
        ${pkgs.yq}/bin/yq -y -i ".providers.zones.directory = \"$zones_dir\"" "$config_file"

        exec ${fullOctodns}/bin/octodns-sync --config-file "$config_file" "$@"
        EOF

        chmod +x $out/bin/octodns-sync
      '';
    };
    #  }}}
  }
