{config, ...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      IdentityFile = config.yomi.pilot.sshIdentity;
    };
  };
  yomi.persistence.at.state.apps.ssh.directories = [".ssh"];
}
