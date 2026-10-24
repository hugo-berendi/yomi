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
  # }}}
  # {{{ Proton mail DNS setup
  # Proton issues the verification token and the DKIM CNAME targets per
  # domain (Settings -> Domain names), so they are passed in, not derived.
  protonMail = at: verifyToken: dkimDomain: let
    atPrefix = prefix:
      if at == ""
      then prefix
      else "${prefix}.${at}";
    dkim = selector: {
      at = atPrefix "${selector}._domainkey";
      type = "CNAME";
      value = "${selector}.domainkey.${dkimDomain}.";
      ttl = 600;
    };
  in [
    {
      inherit at;
      ttl = 600;
      type = "MX";
      value = [
        {
          exchange = "mail.protonmail.ch.";
          preference = 10;
        }
        {
          exchange = "mailsec.protonmail.ch.";
          preference = 20;
        }
      ];
    }
    {
      inherit at;
      ttl = 600;
      type = "TXT";
      value = [
        "v=spf1 include:_spf.protonmail.ch ~all"
        "protonmail-verification=${verifyToken}"
      ];
    }
    {
      at = atPrefix "_dmarc";
      type = "TXT";
      value = ''v=DMARC1\; p=quarantine\;'';
      ttl = 600;
    }
    (dkim "protonmail")
    (dkim "protonmail2")
    (dkim "protonmail3")
  ];
  # }}}
  # {{{ SimpleLogin mail DNS setup
  simpleLoginMail = at: let
    atPrefix = prefix:
      if at == ""
      then prefix
      else "${prefix}.${at}";
  in [
    {
      inherit at;
      ttl = 600;
      type = "MX";
      value = [
        {
          exchange = "mx.hugo-berendi.de.";
          preference = 10;
        }
      ];
    }
    {
      inherit at;
      ttl = 600;
      type = "TXT";
      value = "v=spf1 mx ~all";
    }
    {
      at = atPrefix "_dmarc";
      type = "TXT";
      value = ''v=DMARC1\; p=quarantine\;'';
      ttl = 600;
    }
    {
      at = atPrefix "dkim._domainkey";
      type = "TXT";
      value = ''v=DKIM1\; k=rsa\; p=__SIMPLELOGIN_DKIM_PUBLIC_KEY__'';
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
      # The bare domain moved to Proton; tengu keeps sending service mail
      # through Migadu.
      (protonMail ""
        "6f73dfad8d8d3cf48a45fcefa7e487318cb3b396"
        "dnnrdhxgtnisstbiamas5jw3hf4c32bkkcufe5i63vfslns6uazyq.domains.proton.ch")
      (migaduMail "tengu" "t5fehqan")
      (simpleLoginMail "yokai")
      [
        {
          at = "classattack";
          type = "CNAME";
          value = "expected-bite.gl.at.ply.gg.";
          ttl = 600;
        }
        {
          at = "vrising";
          type = "CNAME";
          value = "wan.hugo-berendi.de.";
          ttl = 600;
        }
        {
          at = "_atproto";
          type = "TXT";
          value = "did=did:plc:xvhbsibo5hrwepntbe3i4qv6";
          ttl = 600;
        }
      ]
    ];
  }
