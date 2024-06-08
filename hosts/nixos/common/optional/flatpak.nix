{lib, ...}: {
  # flatpak
  services.flatpak = {
    enable = true;
    update = {
      onActivation = true;
      auto = {
        enable = true;
        onCalendar = "weekly"; # Default value
      };
    };
    remotes = lib.mkOptionDefault [
      {
        name = "flathub-beta";
        location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
      }
    ];
    overrides = {
      global = {
        # Force Wayland by default
        Context.sockets = ["wayland" "!x11" "!fallback-x11"];
      };
    };
    packages = [
      {
        appId = "dev.vencord.Vesktop";
        origin = "flathub";
      }
      {
        appId = "dev.bragefuglseth.Keypunch";
        origin = "flathub";
      }
      "com.gitlab.tipp10.tipp10"
    ];
  };
}
