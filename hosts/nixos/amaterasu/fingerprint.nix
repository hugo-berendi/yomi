{
  config,
  lib,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
in {
  # {{{ Fingerprint authentication
  services.fprintd.enable = true;

  # Root is rolled back at boot; fprintd's enrollment database must survive.
  yomi.persistence.at.state.apps.fprintd.directories = [
    {
      directory = "/var/lib/fprint";
      mode = "0700";
    }
  ];

  # Try the built-in sensor before waiting for a touch on an inserted YubiKey.
  # A timeout or failed scans still falls through to the existing PAM methods.
  security.pam.services =
    lib.genAttrs ["sudo" "polkit-1" "greetd" "login"] (service: {
      fprintAuth = true;
      rules.auth.fprintd = {
        order = config.security.pam.services.${service}.rules.auth.u2f.order - 10;
        args = ["timeout=10" "max-tries=3"];
      };
    })
    // {
      # Hyprlock reads the sensor directly, alongside password authentication.
      # A second reader in PAM would compete for the same device.
      hyprlock.fprintAuth = false;
      sshd.fprintAuth = false;
    };
  # }}}

  # {{{ Login screen
  # ReGreet follows PAM's conversation: show the scan instruction first and
  # reveal the password field only when PAM actually asks for a password.
  programs.regreet = {
    enable = true;
    settings = {
      appearance.greeting_msg = "Mit Login starten, dann Finger auf den Einschaltknopf legen";
      background.fit = lib.mkForce "Cover";
      widget.clock = {
        format = "%A, %d. %B · %H:%M";
        resolution = "1s";
      };
    };
  };

  stylix.targets.regreet.enable = true;
  stylix.targets.regreet.extraCss = ''
    frame.background {
      background-color: ${colors.base00};
      color: ${colors.base05};
      border: 1px solid ${colors.base0D};
      border-radius: 16px;
      padding: 24px;
      box-shadow: 0 12px 36px alpha(${colors.base00}, 0.58);
    }

    entry, button, combobox button {
      border-radius: 12px;
      padding: 12px 16px;
    }

    button.suggested-action {
      background: ${colors.base0D};
      color: ${colors.base00};
      font-weight: 700;
    }
  '';

  # Remember the selected user/session across root rollbacks.
  yomi.persistence.at.state.apps.regreet.directories = [
    {
      directory = "/var/lib/regreet";
      user = "greeter";
      group = "greeter";
    }
  ];
  # }}}
}
