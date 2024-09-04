# DNS entries which do not belong to a particular host
{lib, ...}: {
  satellite.dns.domain = "hugo-berendi.de";
  satellite.dns.records = lib.flatten [
    # (ghPage "doffycup")
    # (ghPage "erratic-gate")
    # (migaduMail "" "kfkhyexd")
    # (migaduMail "orbit" "24s7lnum")
  ];
}
