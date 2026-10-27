{
  pkgs,
  upkgs,
  inputs,
  ...
}: let
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  codex = import ./features/cli/ai/codex-package.nix {inherit inputs pkgs;};
  t3code-desktop = agents.t3code-desktop.override {
    t3code = agents.t3code.override {
      providerPackages = [codex agents.claude-code agents.opencode];
    };
  };
in {
  imports = [
    ./global.nix

    ./features/wayland/hyprland
    ./features/productivity
    ./features/desktop/t3code.nix
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
      localsend

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
      # sherlock # Search for usernames across different websites
      # }}}
      # {{{ Media playing/recording
      # peek # GIF recorder
      # obs-studio # video recorder
      # }}}
    ];
  };

  home.sessionVariables.QT_SCREEN_SCALE_FACTORS = 1.4; # Bigger text in qt apps

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
