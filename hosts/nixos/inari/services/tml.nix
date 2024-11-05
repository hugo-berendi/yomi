{...}: let
  mods = "";
in {
  virtualisation.oci-containers.containers."tmodloader" = {
    image = "jacobsmile/tmodloader1.4:latest";
    environment = {
      "TMOD_AUTODOWNLOAD" = mods;
      "TMOD_AUTOSAVE_INTERVAL" = "10";
      "TMOD_DIFFICULTY" = "3";
      "TMOD_ENABLEDMODS" = mods;
      "TMOD_MAXPLAYERS" = "5";
      "TMOD_MOTD" = "HeHeHeHa!";
      "TMOD_PASS" = "1234";
      "TMOD_SHUTDOWN_MESSAGE" = "Goodbye!";
      "TMOD_USECONFIGFILE" = "No";
      "TMOD_WORLDNAME" = "The World";
      "TMOD_WORLDSEED" = "not the bees!";
      "TMOD_WORLDSIZE" = "2";
      "UPDATE_NOTICE" = "false";
    };
    volumes = [
      "/home/hugob/projects/tml/data:/data:rw"
    ];
    ports = [
      "7777:7777/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=tmodloader"
      "--network=tml_default"
    ];
  };
}
