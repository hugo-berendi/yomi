{
  pkgs,
  config,
}: let
  original = config.systemd.services.nftables.serviceConfig;
in
  pkgs.testers.runNixOSTest {
    name = "inari-firewall-reload";
    nodes.machine = {lib, ...}: {
      networking.firewall.enable = false;
      networking.nftables = config.networking.nftables;
      systemd.services.nftables.serviceConfig = {
        inherit (original) RuntimeDirectory ExecStartPre;
        ExecStartPost = lib.mkAfter [(lib.last original.ExecStartPost)];
        ExecReload = lib.mkMerge [
          (lib.mkBefore [(builtins.head original.ExecReload)])
          (lib.mkAfter [(lib.last original.ExecReload)])
        ];
      };
      # A Docker stand-in records restart requests without pulling images.
      # The separately owned nftables table represents rules installed by Docker.
      systemd.services.docker = {
        wantedBy = ["multi-user.target"];
        script = ''
          echo start >> /run/docker-starts
          exec ${pkgs.coreutils}/bin/sleep infinity
        '';
      };
      environment.systemPackages = [pkgs.nftables];
    };
    testScript = ''
      machine.start()
      machine.wait_for_unit("docker.service")
      machine.wait_for_unit("nftables.service")
      machine.succeed("nft add table ip docker_owned")
      machine.succeed("nft add chain ip docker_owned sentinel")
      machine.succeed("nft add rule ip docker_owned sentinel counter accept")
      machine.succeed("systemctl reload nftables")
      machine.succeed("systemctl reload nftables")
      machine.succeed("nft list chain ip docker_owned sentinel | grep 'counter.*accept'")
      machine.succeed("test $(wc -l < /run/docker-starts) -eq 1")
      # An existing installation still has the old global deletion script.
      machine.succeed("printf 'flush ruleset\\n' > /var/lib/nftables/deletions.nft")
      machine.succeed("systemctl reload nftables")
      machine.wait_until_succeeds("test $(wc -l < /run/docker-starts) -eq 2")
      machine.succeed("nft add table ip docker_owned")
      machine.succeed("nft add chain ip docker_owned sentinel")
      machine.succeed("nft add rule ip docker_owned sentinel counter accept")
      machine.succeed("systemctl reload nftables")
      machine.succeed("nft list chain ip docker_owned sentinel | grep 'counter.*accept'")
      machine.succeed("test $(wc -l < /run/docker-starts) -eq 2")
      machine.succeed("nft list table inet yomi-filter")
      machine.succeed("nft list table ip yomi-nat")
    '';
  }
