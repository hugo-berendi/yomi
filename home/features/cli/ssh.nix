{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      identityFile = "~/.ssh/id_ed25519";
    };
  };
  yomi.persistence.at.state.apps.ssh.directories = [".ssh"];
}
