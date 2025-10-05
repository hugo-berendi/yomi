{lib, ...}: {
  services.flatpak = {
    enable = true;

    # {{{ Update settings
    update = {
      onActivation = true;
      auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };
    # }}}
    # {{{ Remotes
    remotes = lib.mkOptionDefault [
      {
        name = "flathub-beta";
        location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
      }
    ];
    # }}}
    # {{{ Overrides
    overrides = {
      global = {
        Context.sockets = ["wayland" "!x11" "!fallback-x11"];
      };
    };
    # }}}
    # {{{ Packages
    packages = [
      {
        appId = "dev.bragefuglseth.Keypunch";
        origin = "flathub";
      }
      "com.gitlab.tipp10.tipp10"
    ];
    # }}}
  };
}
