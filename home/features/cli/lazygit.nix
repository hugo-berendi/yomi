{config, ...}: {
  programs.lazygit = {
    enable = true;
    settings = {
      promptToReturnFromSubprocess = false;
      disableStartupPopups = true;
    };
  };

  yomi.persistence.at.state.apps.lazygit.directories = ["${config.xdg.configHome}/lazygit"];
}
