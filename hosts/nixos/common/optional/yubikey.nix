{pkgs, ...}: let
  mapping = "hugob:pD4pbC6iobeS2aZJ5lAsL4gIzU9E4AN6qlekI778HuiM+ufh1y8fLH86RTc05y17U8eiFC0v+EO1WYINt1OxUg==,dG/eVQL1+K+A0BC2wcxWs+7s03BaI8g1QgTIQBk8qJrE4v3xQbNHHdkQMAxkBA3uGXXgOfZ4diANIGXtvsRmFA==,es256,+presence";
in {
  # {{{ Home Manager
  home-manager.users.pilot = {...}: {
    xdg.configFile."Yubico/u2f_keys".text = mapping;
  };
  # }}}
  # {{{ Programs
  programs.ssh.startAgent = false;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  # }}}
  # {{{ Services
  services.udev.packages = [pkgs.yubikey-personalization];
  services.pcscd.enable = true;
  # }}}
  # {{{ PAM
  security.pam.yubico = {
    enable = true;
    mode = "challenge-response";
    id = ["30636315"];
  };
  # }}}
  # {{{ Environment
  environment.shellInit = ''
    gpg-connect-agent /bye
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  '';
  # }}}
  # {{{ User packages
  users.users.pilot.packages = [
    pkgs.yubioath-flutter
    pkgs.yubikey-personalization
  ];
  # }}}
}
