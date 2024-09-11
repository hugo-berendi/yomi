# DNS entries which do not belong to a particular host
{lib, ...}: {
  yomi.dns.domain = "hugo-berendi.de";
  yomi.dns.records = lib.flatten [
    # (ghPage "doffycup")
    # (ghPage "erratic-gate")
    # (migaduMail "" "kfkhyexd")
    # (migaduMail "orbit" "24s7lnum")
  ];
}
