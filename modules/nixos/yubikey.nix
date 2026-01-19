{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  cfg = config.yomi.yubikey;
in {
  options.yomi.yubikey = {
    enable = lib.mkEnableOption "YubiKey integration";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users who will use YubiKey for authentication";
    };

    pam = {
      u2f = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable U2F authentication via PAM";
        };

        appId = lib.mkOption {
          type = lib.types.str;
          default = "pam://yomi";
          description = "Application ID for U2F (allows cross-device key sharing)";
        };

        secretPath = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to sops secret containing U2F mappings";
        };
      };

      challengeResponse = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable challenge-response mode";
        };

        ids = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "YubiKey device IDs for challenge-response";
        };
      };
    };

    ssh = {
      enableAgent = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSH agent support via GPG agent";
      };

      publicKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "GPG SSH key IDs to use";
      };
    };

    age = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable AGE encryption with YubiKey plugin";
      };

      recipients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "YubiKey AGE recipient strings";
      };
    };

    touchDetector = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable YubiKey touch detector for notifications";
      };
    };

    lockOnRemoval = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Lock session when YubiKey is removed";
      };

      lockCommand = lib.mkOption {
        type = lib.types.str;
        default = "${pkgs.systemd}/bin/loginctl lock-sessions";
        description = "Command to run when YubiKey is removed";
      };
    };
  };

  config = lib.mkMerge ([
      (lib.mkIf cfg.enable {
        security.pam.services = lib.mkMerge [
          (lib.mkIf cfg.pam.u2f.enable {
            login.u2fAuth = true;
            sudo.u2fAuth = true;
            polkit.u2fAuth = true;
            gdm.u2fAuth = true;
            greetd.u2fAuth = true;
          })
          (lib.mkIf cfg.pam.challengeResponse.enable {
            login.yubicoAuth = true;
            sudo.yubicoAuth = true;
          })
        ];

        security.pam.u2f = lib.mkIf cfg.pam.u2f.enable {
          enable = true;
          control = "sufficient";
          settings = {
            cue = true;
            appid = cfg.pam.u2f.appId;
          };
        };

        security.pam.yubico = lib.mkIf cfg.pam.challengeResponse.enable {
          enable = true;
          mode = "challenge-response";
          id = cfg.pam.challengeResponse.ids;
        };

        programs.ssh.startAgent = lib.mkIf cfg.ssh.enableAgent false;

        programs.gnupg.agent = lib.mkIf cfg.ssh.enableAgent {
          enable = true;
          enableSSHSupport = true;
        };

        environment.shellInit = lib.mkIf cfg.ssh.enableAgent ''
          gpg-connect-agent /bye 2>/dev/null
          export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
        '';

        services.udev.packages = [pkgs.yubikey-personalization];
        services.pcscd.enable = true;

        services.udev.extraRules = lib.mkIf cfg.lockOnRemoval.enable ''
          ACTION=="remove", ENV{ID_VENDOR_ID}=="1050", RUN+="${cfg.lockOnRemoval.lockCommand}"
        '';

        systemd.user.services.yubikey-touch-detector = lib.mkIf cfg.touchDetector.enable {
          description = "YubiKey touch detector";
          wantedBy = ["graphical-session.target"];
          serviceConfig = {
            ExecStart = "${pkgs.yubikey-touch-detector}/bin/yubikey-touch-detector --libnotify";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        environment.systemPackages = with pkgs;
          [
            yubikey-manager
            yubikey-personalization
            yubioath-flutter
          ]
          ++ lib.optionals cfg.age.enable [
            rage
            age-plugin-yubikey
          ];

        environment.sessionVariables = lib.mkIf cfg.age.enable {
          YOMI_YUBI_AGE_RECIPIENTS = lib.concatStringsSep "," cfg.age.recipients;
        };

        sops.secrets = lib.mkIf (cfg.pam.u2f.enable && cfg.pam.u2f.secretPath != null) {
          "yubikey/u2f_keys" = {
            sopsFile = cfg.pam.u2f.secretPath;
            mode = "0644";
          };
        };

        systemd.services = lib.mkIf (cfg.pam.u2f.enable && cfg.pam.u2f.secretPath != null) (
          lib.genAttrs (map (user: "yubikey-u2f-link-${user}") cfg.users) (name: let
            user = builtins.replaceStrings ["yubikey-u2f-link-"] [""] name;
          in {
            description = "Link YubiKey U2F keys for ${user}";
            wantedBy = ["multi-user.target"];
            after = ["sops-nix.service"];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = user;
            };
            script = ''
              mkdir -p "$HOME/.config/Yubico"
              ln -sf ${config.sops.secrets."yubikey/u2f_keys".path} "$HOME/.config/Yubico/u2f_keys"
            '';
          })
        );
      })
    ]
    ++ lib.optionals (options ? home-manager) [
      {
        home-manager.users = lib.mkIf cfg.enable (lib.genAttrs cfg.users (user: {
          services.gpg-agent = lib.mkIf cfg.ssh.enableAgent {
            enable = true;
            sshKeys = cfg.ssh.publicKeys;
            pinentry.package = lib.mkDefault pkgs.pinentry-curses;
            enableFishIntegration = true;
            extraConfig = ''
              no-allow-external-cache
            '';
          };

          yomi.persistence.at.state.apps.yubico.directories = [
            ".yubico"
          ];
        }));
      }
    ]);
}
