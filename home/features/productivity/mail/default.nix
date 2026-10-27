{
  config,
  pkgs,
  ...
}: let
  # The Bridge password, kept in 1Password (Automation vault, item "Proton
  # Mail Bridge (inari)"), referenced by ID as op read rejects the
  # parentheses in the title.
  bridgePasswordRef = "op://Automation/fjgnyfe4s4lrreazuvv2j7ouwe/password";
  # Read once per login into the per-user tmpfs. mbsync syncs on a timer,
  # and an `op read` on every run would ask the app for approval every time.
  bridgePasswordFile = "\$XDG_RUNTIME_DIR/bridge-mail-password";
  op = "/run/wrappers/bin/op";
  readBridgePassword = pkgs.writeShellScript "bridge-mail-password" ''
    if [ -s "${bridgePasswordFile}" ]; then
      exec cat "${bridgePasswordFile}"
    fi
    exec ${op} read --no-newline ${bridgePasswordRef}
  '';
in {
  imports = [
    ./msmtp.nix
    ./mbsync.nix
    ./notmuch.nix
    ./aerc.nix
    ./neomutt.nix
    ./neomutt-theme.nix
    ./thunderbird.nix
    ./persistence.nix
  ];

  # {{{ Sops secrets
  sops.secrets.outlook_mail_pass.sopsFile = ../secrets.yaml;
  # }}}

  accounts.email.accounts = {
    # {{{ hugob
    hugob = rec {
      # {{{ Primary config
      address = "personal@hugo-berendi.de";
      realName = "Hugo Berendi";
      userName = address;
      aliases = ["git@hugo-berendi.de"];

      folders = {
        inbox = "INBOX";
        sent = "Sent";
        drafts = "Drafts";
        trash = "Trash";
      };

      # Signs with the YubiKey's subkey. Mail is only on hosts that have the
      # card. Not encryptByDefault: that would break mail to anyone without a
      # key.
      gpg = {
        key = config.yomi.pilot.gpgKey;
        signByDefault = true;
      };

      passwordCommand = "${readBridgePassword}";
      primary = true;
      # }}}
      # {{{ Imap / smtp configuration
      # Proton Mail Bridge on inari, over the tailnet: nginx terminates TLS
      # with a real certificate and hands off to Bridge through a pinned
      # STARTTLS relay (hosts/nixos/inari/services/protonmail-bridge/default.nix).
      # The password is the Bridge's own (its `info` command), not the
      # Proton account password.
      imap = {
        host = "mail.hugo-berendi.de";
        port = 993;
      };

      smtp = {
        host = "mail.hugo-berendi.de";
        port = 465;
      };
      # }}}
    };
    # }}}
  };

  # {{{ Bridge password
  # Fills bridgePasswordFile at login. The first read asks the 1Password app
  # for approval, which is the one prompt per session. Gone on logout, as
  # $XDG_RUNTIME_DIR is.
  systemd.user.services.bridge-mail-password = {
    Unit = {
      Description = "Fetch the Proton Bridge password from 1Password";
      After = ["graphical-session.target" "1password.service"];
      Wants = ["1password.service"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
      ExecStart = pkgs.writeShellScript "fetch-bridge-mail-password" ''
        set -euo pipefail
        file="$XDG_RUNTIME_DIR/bridge-mail-password"
        ${op} read --no-newline ${bridgePasswordRef} > "$file.tmp"
        mv "$file.tmp" "$file"
      '';
      ExecStop = "${pkgs.coreutils}/bin/rm -f %t/bridge-mail-password";
      # The app may still be starting or locked when the session comes up.
      Restart = "on-failure";
      RestartSec = 30;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
  # }}}
}
