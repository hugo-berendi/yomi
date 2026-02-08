{
  pkgs,
  self,
  ...
}: rec {
  octodns-zones = let
    nixosConfigModules =
      pkgs.lib.mapAttrsToList
      (_: current: {yomi.dns = current.config.yomi.dns;})
      self.nixosConfigurations;

    evaluated = pkgs.lib.evalModules {
      specialArgs = {inherit pkgs;};
      modules =
        [
          ../modules/nixos/dns.nix
          ../modules/common/octodns.nix
          ./common.nix
        ]
        ++ nixosConfigModules;
    };
  in
    evaluated.config.yomi.dns.octodns;
  octodns-sync = pkgs.symlinkJoin {
    name = "octodns-sync";
    paths = [self.packages.${pkgs.stdenv.hostPlatform.system}.octodns];
    buildInputs = [pkgs.makeWrapper pkgs.yq];
    postBuild = ''
      cat ${./octodns.yaml} | yq '.providers.zones.directory="${octodns-zones}"' > $out/config.yaml
      wrapProgram $out/bin/octodns-sync \
        --run 'export CLOUDFLARE_TOKEN=$( \
            sops \
              --decrypt \
              --extract "[\"cloudflare_dns_api_token\"]" \
              ./hosts/nixos/common/secrets.yaml \
          )' \
        --add-flags "--config-file $out/config.yaml"
    '';
  };
}
