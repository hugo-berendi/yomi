{
  config,
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
    file = {};
    sessionVariables = {EDITOR = "nvim";};
    packages = with pkgs; [
      localsend

      prismlauncher
      pay-respects
      sxiv
      t3code-desktop
      # {{{ messaging
      signal-desktop
      upkgs.fluffychat
      # }}}
      qbittorrent
      # upkgs.unityhub
      # upkgs.nerdfetch # for displaying pc/laptop stats
      upkgs.nh
      upkgs.nix-output-monitor
      upkgs.nvd

      lutris

      gtk3 # needed for gtk-launch

      # {{{ Clis
      sops # Secret editing
      # sherlock # Search for usernames across different websites
      # }}}
      # {{{ Media playing/recording
      mpv # Video player
      imv # Image viewer
      # peek # GIF recorder
      # obs-studio # video recorder
      # }}}

      # {{{ java development
      # jetbrains.idea-ultimate
      # jetbrains.jdk
      # }}}
    ];
  };

  home.sessionVariables.QT_SCREEN_SCALE_FACTORS = 1.4; # Bigger text in qt apps

  # {{{ T3 Code
  # ~/.t3 holds the server's sessions. The desktop app's own Electron profile
  # is separate, and it is where the UI keeps its settings -- installed
  # themes included, in localStorage under `t3code:themes:v1`. Unpersisted,
  # it came back empty on every boot, so an imported theme lasted until the
  # next reboot and only the built-in ones ever seemed to exist.
  yomi.persistence.at.state.apps.t3code.directories = [
    "${config.home.homeDirectory}/.t3"
    "${config.xdg.configHome}/T3 Code (Alpha)"
  ];

  # T3 Code has no theme directory to drop this into; the library lives in
  # localStorage. Import it once through Settings -> Colors & themes ->
  # Import, which now survives reboots. Roles left out fall back to the
  # built-in dark theme, and the import accepts any CSS colour, hex included.
  xdg.dataFile."t3code/stylix.json".text = let
    c = config.lib.stylix.colors.withHashtag;
  in
    builtins.toJSON {
      version = 1;
      id = "stylix";
      name = "Stylix (${config.lib.stylix.colors.scheme})";
      appearance = config.stylix.polarity;
      colors = {
        canvas = c.base00;
        chrome = c.base00;
        toolbar = c.base00;
        toolbarForeground = c.base05;
        toolbarBorder = c.base02;
        toolbarControl = c.base01;
        toolbarControlForeground = c.base05;
        toolbarControlHover = c.base02;
        surface = c.base01;
        surfaceRaised = c.base01;
        surfaceOverlay = c.base01;
        text = c.base05;
        textMuted = c.base04;
        border = c.base02;
        input = c.base02;
        focus = c.base0D;
        accent = c.base0D;
        accentForeground = c.base00;
        secondary = c.base02;
        secondaryForeground = c.base05;
        muted = c.base02;
        mutedForeground = c.base04;
        placeholder = c.base03;
        secondaryLabel = c.base04;
        iconMuted = c.base04;
        error = c.base08;
        errorForeground = c.base08;
        errorSurface = c.base01;
        warning = c.base09;
        warningForeground = c.base09;
        warningSurface = c.base01;
        update = c.base0C;
        updateForeground = c.base0C;
        updateSurface = c.base01;
        accentSurface = c.base02;
        accentSurfaceForeground = c.base05;
        messageSurface = c.base01;
        messageForeground = c.base05;
        messageAction = c.base0D;
        messageActionForeground = c.base00;
        messageActionHover = c.base0E;
        codeBackground = c.base01;
        codeForeground = c.base05;
        sidebar = c.base01;
        sidebarForeground = c.base05;
        sidebarMutedForeground = c.base04;
        sidebarControlSurface = c.base02;
        sidebarRowHover = c.base02;
        sidebarRowActive = c.base02;
        sidebarRowSelected = c.base02;
        sidebarBorder = c.base02;
        terminalBackground = c.base00;
        terminalForeground = c.base05;
        terminalCursor = c.base05;
        terminalSelection = c.base02;
        terminalScrollbar = c.base02;
        terminalScrollbarHover = c.base03;
      };
    };
  # }}}

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

  yomi.toggles.isServer.enable = false;
  yomi = {
    # Symlink some commonly modified dotfiles outside the nix store
    dev.enable = true;

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
