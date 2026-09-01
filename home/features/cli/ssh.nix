{config, ...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      identityFile = config.yomi.pilot.sshIdentity;
    };
  };
  yomi.persistence.at.state.apps.ssh.directories = [".ssh"];
}
