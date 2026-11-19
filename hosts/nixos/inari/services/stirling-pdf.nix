{
  config,
  lib,
  ...
}: {
  yomi.nginx.at.pdf.port = config.yomi.ports.stirling-pdf;

  # {{{ OCR languages
  # The stirling-pdf module puts pkgs.tesseract and ocrmypdf on its path and
  # bind-mounts tesseract's tessdata; by default that ships every language
  # (~1 GiB). Override tesseract5, which ocrmypdf takes directly and which
  # pkgs.tesseract aliases. Paperless builds its own copy from
  # PAPERLESS_OCR_LANGUAGE; listing the languages in the same order as the
  # paperless module does lets both resolve to one store path. Stirling's OCR
  # offers only these languages afterwards.
  nixpkgs.overlays = [
    (_final: prev: {
      tesseract5 = prev.tesseract5.override {
        enableLanguages = ["equ" "osd" "eng" "deu"];
      };
    })
  ];
  # }}}

  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = config.yomi.nginx.at.pdf.port;
    };
  };

  systemd.services.stirling-pdf.serviceConfig = lib.mkMerge [
    {
      PrivateTmp = true;
      ProtectSystem = "strict";
      PrivateMounts = true;
      RestrictSUIDSGID = true;
    }
  ];
}
