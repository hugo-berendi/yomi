{config, ...}: {
  yomi.yubikey = {
    enable = false;
    users = ["pilot"];

    pam = {
      u2f = {
        enable = true;
        appId = "pam://yomi";
        secretPath = ../secrets.yaml;
      };

      challengeResponse = {
        enable = true;
        ids = ["30636315"];
      };
    };

    ssh = {
      enableAgent = true;
      publicKeys = ["67D63C5F40CC55DA"];
    };

    age = {
      enable = true;
      recipients = [];
    };

    touchDetector.enable = true;
    lockOnRemoval.enable = true;
  };
}
