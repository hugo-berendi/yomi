# DNS entries which do not belong to a particular host
{lib, ...}: let
  # {{{ Github pages helper
  # }}}
  # {{{ Migadu mail DNS setup
  migaduMail = at: verifyKey: let
    atPrefix = prefix:
      if at == ""
      then prefix
      else "${prefix}.${at}";
    keyValue = keyNum:
      if at == ""
      then "key${builtins.toString keyNum}.hugo-berendi.de._domainkey.migadu.com."
      else "key${builtins.toString keyNum}.${at}.hugo-berendi.de._domainkey.migadu.com.";
  in [
    {
      inherit at;
      ttl = 600;
      type = "MX";
      value = [
        {
          exchange = "aspmx1.migadu.com.";
          preference = 10;
        }
        {
          exchange = "aspmx2.migadu.com.";
          preference = 20;
        }
      ];
    }
    {
      inherit at;
      ttl = 600;
      type = "TXT";
      value = [
        "v=spf1 include:spf.migadu.com -all"
        "hosted-email-verify=${verifyKey}"
      ];
    }
    {
      at = atPrefix "_dmarc";
      type = "TXT";
      value = ''v=DMARC1\; p=quarantine\;'';
      ttl = 600;
    }
    {
      at = atPrefix "key1._domainkey";
      type = "CNAME";
      value = keyValue 1;
      ttl = 600;
    }
    {
      at = atPrefix "key2._domainkey";
      type = "CNAME";
      value = keyValue 2;
      ttl = 600;
    }
    {
      at = atPrefix "key3._domainkey";
      type = "CNAME";
      value = keyValue 3;
      ttl = 600;
    }
  ];
in
  # }}}
  {
    yomi.dns.records = lib.flatten [
      # (ghPage "doffycup")
      # (ghPage "erratic-gate")
      # (ghPage "giftstogo")
      (migaduMail "" "xmycngew")
      (migaduMail "tengu" "t5fehqan")
      [
        {
          at = "classattack";
          type = "CNAME";
          value = "expected-bite.gl.at.ply.gg.";
          ttl = 600;
        }
        {
          at = "node1.pelican";
          type = "CNAME";
          value = "dynamic.hugo-berendi.de.";
          ttl = 300;
        }
      ]
    ];
  }
