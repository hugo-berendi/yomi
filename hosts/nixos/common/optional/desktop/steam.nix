{...}: {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    gamescopeSession.enable = true;
  };
  # Persist Steam libraries and metadata with impermanence
  environment.persistence."/persist/state".directories = [
    "/home/hugob/.steam"
    "/home/hugob/.local/share/Steam"
  ];
}
