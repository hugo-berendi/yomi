{
  config,
  lib,
  pkgs,
  upkgs,
  inputs,
  ...
}: let
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  codex = import ../../../features/cli/ai/codex-package.nix {inherit inputs pkgs;};
  claudeCode = import ../../../features/cli/ai/claude-code-package.nix {inherit inputs pkgs;};
  t3code-desktop = agents.t3code-desktop.override {
    t3code = import ../../../features/desktop/t3code-package.nix {
      inherit inputs pkgs;
      providerPackages = [codex claudeCode agents.opencode agents.copilot-cli];
    };
  };
in {
  imports = [
    ../../../features/productivity
    ../../../features/desktop/t3code.nix
  ];

  # {{{ Fcitx5 keyboard configuration
  i18n.inputMethod.fcitx5.settings.inputMethod = {
    "Groups/0" = {
      Name = "Default";
      "Default Layout" = "de";
      DefaultIM = "keyboard-de";
    };
    "Groups/0/Items/0" = {
      Name = "keyboard-de";
      Layout = "";
    };
    GroupOrder = {
      "0" = "Default";
    };
  };
  # }}}

  home = {
    packages = with pkgs; [
      # localsend comes from programs.localsend in hosts/nixos/amaterasu.
      prismlauncher
      t3code-desktop
      # {{{ messaging
      signal-desktop
      upkgs.fluffychat
      # }}}
      qbittorrent
      # upkgs.nerdfetch # for displaying pc/laptop stats

      lutris

      gtk3 # needed for gtk-launch

      # {{{ Clis
      upkgs.forgejo-cli # fj; t3code's Forgejo integration needs 0.6+, which stable lacks
      # sherlock # Search for usernames across different websites
      # }}}
      # {{{ Media playing/recording
      # peek # GIF recorder
      # obs-studio # video recorder
      # }}}
    ];
  };

  home.sessionVariables.QT_SCREEN_SCALE_FACTORS = 1.4; # Bigger text in qt apps

  programs.hyprlock.settings.auth.fingerprint = {
    enabled = true;
    ready_message = "Finger auf den Sensor legen";
    present_message = "Fingerabdruck wird geprüft";
  };

  # {{{ SSH identity
  # The YubiKey's resident FIDO2 key first, the old shared key as a fallback
  # until the sops/ZFS recovery path no longer depends on it.
  yomi.pilot.sshIdentity = ["~/.ssh/id_ed25519_sk" "~/.ssh/id_ed25519"];

  # The FIDO2 key is verify-required, so an agent holding it would have to ask
  # for the PIN itself, and there is no askpass here to do that. Once added,
  # every signature through the agent fails and ssh falls back to the old key.
  # Keep keys out of the agent; ssh prompts for the PIN on the terminal.
  programs.ssh.settings."*".AddKeysToAgent = "no";
  # }}}

  # {{{ Smartcard
  # Reach the card through pcscd (see hosts/nixos/amaterasu), and share it,
  # so ykman and age-plugin-yubikey still work while gpg-agent is running.
  #
  # The signature PIN policy is "once" (ykman openpgp info), so the card
  # stays verified for as long as it stays powered. card-timeout powers it
  # down after ten minutes with no card use, which drops that verification:
  # the PIN is asked when the key goes in and again after ten idle minutes,
  # not on every signature. GnuPG 2.4 still accepts the option
  # (gpgconf --list-options scdaemon).
  programs.gpg.scdaemonSettings = {
    disable-ccid = true;
    pcsc-shared = true;
    card-timeout = "600";
  };

  # The YubiKey holds the signing subkey of yomi.pilot.gpgKey, so this is the
  # host that signs. Its touch policy is "cached", so a rebase re-signing a
  # run of commits needs one touch per 15 seconds rather than one per commit.
  programs.git.settings = {
    commit.gpgsign = true;
    tag.gpgsign = true;
  };
  # }}}

  # {{{ LocalSend
  # Device name, received-files folder and trusted devices.
  yomi.persistence.at.state.apps.localsend.directories = [
    "${config.xdg.dataHome}/org.localsend.localsend_app"
  ];
  # }}}
  # {{{ Internal microphone
  # On the Framework 13 AMD the internal microphones only record once the
  # Family 17h/19h audio controller is switched to its "HiFi (Mic1, Mic2,
  # Speaker)" profile; the profile WirePlumber picks by itself leaves them
  # silent. Omarchy applies the same fix at login (fix-f13-amd-audio-input.sh).
  # The unit only sets the profile when that card and profile exist, so it
  # is harmless on a dock or after a firmware change renames them.
  systemd.user.services.framework-mic-profile = {
    Unit = {
      Description = "Select the Framework 13 AMD HiFi profile with internal microphones";
      After = ["wireplumber.service"];
      Wants = ["wireplumber.service"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe (pkgs.writeShellApplication {
        name = "framework-mic-profile";
        runtimeInputs = [pkgs.pulseaudio pkgs.gnugrep pkgs.gawk pkgs.coreutils];
        text = ''
          profile="HiFi (Mic1, Mic2, Speaker)"
          # PipeWire takes a moment after wireplumber starts to list cards.
          for _ in $(seq 10); do
            card=$(pactl list cards 2>/dev/null \
              | grep -B20 "Family 17h/19h" | awk '/Name: /{print $2}' | head -n1 || true)
            [ -n "$card" ] && break
            sleep 1
          done
          if [ -z "$card" ]; then
            echo "no Family 17h/19h card; nothing to do"
            exit 0
          fi
          if pactl list cards | grep -qF "$profile:"; then
            pactl set-card-profile "$card" "$profile"
            echo "set $card to $profile"
          else
            echo "$card has no profile '$profile'; leaving it alone"
          fi
        '';
      });
    };
    Install.WantedBy = ["graphical-session.target"];
  };
  # }}}

  yomi = {
    monitors = [
      {
        name = "DP-2";
        width = 2560;
        height = 1440;
        refreshRate = 165;
        x = 0;
        y = 0;
        workspace = "1";
      }
      {
        name = "eDP-1";
        width = 2256;
        height = 1504;
        x = 2560;
        y = 0;
        workspace = "6";
      }
    ];
  };
}
