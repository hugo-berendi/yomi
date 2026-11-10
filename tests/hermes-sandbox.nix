{
  pkgs,
  configuration,
}: let
  testConfig = configuration.config.system.build.hermes-sandbox-test-config;
in
  pkgs.testers.runNixOSTest {
    name = "hermes-read-only-sandbox";
    nodes.machine = {
      networking.hostName = "t3code-vm";
      users.users.agent = {
        isNormalUser = true;
        extraGroups = ["wheel"];
      };
      security.sudo.wheelNeedsPassword = false;
      virtualisation.memorySize = 2048;
      environment.systemPackages = [pkgs.python3];
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("su -s ${pkgs.bash}/bin/bash agent -c '${pkgs.python3}/bin/python3 ${../modules/nixos/hermes-dispatcher/check_sandbox.py} ${testConfig}'", timeout=240)
    '';
  }
