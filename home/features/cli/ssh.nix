{...}: {
  programs.ssh.enable = true;
  yomi.persistence.at.state.apps.ssh.directories = [".ssh"];
}
