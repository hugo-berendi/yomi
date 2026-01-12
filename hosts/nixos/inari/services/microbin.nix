{
  config,
  lib,
  ...
}: {
  # {{{ Secrets
  sops.secrets.microbin_env.sopsFile = ../secrets.yaml;
  # }}}
  # {{{ Reverse proxy
  yomi.cloudflared.at.bin.port = config.yomi.ports.microbin;
  # }}}
  # {{{ Service
  services.microbin = {
    enable = true;
    dataDir = "/var/lib/microbin";
    passwordFile = config.sops.secrets.microbin_env.path;

    settings = {
      MICROBIN_ADMIN_USERNAME = "hugo-berendi";
      MICROBIN_PORT = toString config.yomi.cloudflared.at.bin.port;
      MICROBIN_PUBLIC_PATH = config.yomi.cloudflared.at.bin.url;
      MICROBIN_DEFAULT_EXPIRY = "1week";

      MICROBIN_DISABLE_TELEMETRY = "true";
      MICROBIN_DISABLE_UPDATE_CHECKING = "true";

      MICROBIN_HIGHLIGHTSYNTAX = "true";
      MICROBIN_QR = "true";
      MICROBIN_READONLY = "true";

      MICROBIN_EDITABLE = "false";
      MICROBIN_ENABLE_BURN_AFTER = "false";
      MICROBIN_ENABLE_READONLY = "false";
      MICROBIN_ETERNAL_PASTA = "false";
      MICROBIN_SHOW_READ_STATS = "false";

      MICROBIN_HIDE_FOOTER = "true";
      MICROBIN_HIDE_HEADER = "true";
      MICROBIN_HIDE_LOGO = "true";
    };
  };

  systemd.services.microbin.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
    {ReadWritePaths = lib.mkForce [];}
  ];
  # }}}

}
