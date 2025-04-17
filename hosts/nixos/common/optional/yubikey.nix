{pkgs, ...}: let
  mapping = "hugob:pD4pbC6iobeS2aZJ5lAsL4gIzU9E4AN6qlekI778HuiM+ufh1y8fLH86RTc05y17U8eiFC0v+EO1WYINt1OxUg==,dG/eVQL1+K+A0BC2wcxWs+7s03BaI8g1QgTIQBk8qJrE4v3xQbNHHdkQMAxkBA3uGXXgOfZ4diANIGXtvsRmFA==,es256,+presence";
in {
  home-manager.users.pilot = { ...}: {
    xdg.configFile."Yubico/u2f_keys".text = mapping;
  };

  programs.ssh.startAgent = false;

  services.udev.packages = [pkgs.yubikey-personalization];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  environment.shellInit = ''
    gpg-connect-agent /bye
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  '';

  users.users.pilot.packages = [
    pkgs.yubioath-flutter
    pkgs.yubikey-personalization
    pkgs.yubikey-manager-qt
  ];

  security.pam = {
    yubico = {
      enable = true;
      # debug = true; # fucks up
      mode = "challenge-response";
      id = ["30636315"];
    };
    # services = {
    #   login.u2fAuth = true;
    #   sudo.u2fAuth = true;
    # };
  };

  services.pcscd.enable = true;
}
