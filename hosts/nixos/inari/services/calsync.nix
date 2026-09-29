{
  config,
  lib,
  pkgs,
  ...
}: let
  port = config.yomi.ports.calsync;
  endpoint = config.yomi.cloudflared.at.calsync;
  contact = "personal@hugo-berendi.de";

  # Google will not publish an OAuth app (and so stops expiring its refresh
  # token every seven days) until Branding links a public homepage and
  # privacy policy on a domain the owner controls. These pages describe the
  # vdirsyncer job in radicale.nix as it actually is; keep them in step with
  # it, in particular the scope and where the token lives.
  page = title: body:
    pkgs.writeText "${lib.toLower title}.html" ''
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>${lib.optionalString (title != "calsync") "${title} · "}calsync</title>
        <style>
          body { font: 16px/1.6 system-ui, sans-serif; max-width: 42rem; margin: 3rem auto; padding: 0 1rem; }
          nav a { margin-right: 1rem; }
        </style>
      </head>
      <body>
        <nav><a href="/">calsync</a><a href="/privacy.html">Privacy</a><a href="/terms.html">Terms</a></nav>
        <h1>${title}</h1>
        ${body}
        <p><small>Contact: <a href="mailto:${contact}">${contact}</a></small></p>
      </body>
      </html>
    '';

  site = pkgs.linkFarm "calsync-site" {
    "index.html" = page "calsync" ''
      <p>calsync is a personal calendar synchronisation job run by Hugo Berendi
      on a server he owns. It keeps events in his self-hosted
      <a href="https://radicale.org">Radicale</a> calendar and his own Google
      Calendar in step, in both directions, using
      <a href="https://vdirsyncer.pimutils.org">vdirsyncer</a> over Google's
      CalDAV interface.</p>
      <p>It is not a public service. It connects only the operator's own Google
      account, and nobody else can sign up for or use it.</p>
      <p>See the <a href="/privacy.html">privacy policy</a> and the
      <a href="/terms.html">terms of use</a>.</p>
    '';

    "privacy.html" = page "Privacy" ''
      <h2>Whose data</h2>
      <p>calsync connects exactly one Google account: the operator's own. It is
      not offered to anyone else, so it processes no other person's account.</p>

      <h2>What it accesses</h2>
      <p>With the <code>https://www.googleapis.com/auth/calendar</code> scope,
      calsync reads, creates, changes and deletes calendar events in the Google
      calendars the operator has explicitly paired with calendars in his Radicale
      server. Events can contain details of other people, such as attendees'
      names and e-mail addresses, when those are part of an event.</p>

      <h2>Where it is stored</h2>
      <p>Synchronised events are stored in the operator's Radicale server. The
      OAuth token Google issues is stored on the same server, in a directory
      readable only by the dedicated system account that runs the sync, and is
      included in that server's encrypted backups. The OAuth client secret is
      kept encrypted in the server's configuration.</p>

      <h2>Sharing</h2>
      <p>No data is sold, shared with third parties, used for advertising or
      analytics, or used to train AI models. Data received from Google APIs is
      used only to synchronise these calendars, in line with the
      <a href="https://developers.google.com/terms/api-services-user-data-policy">Google
      API Services User Data Policy</a>, including its Limited Use requirements.</p>

      <h2>Removal</h2>
      <p>Access can be revoked at any time at
      <a href="https://myaccount.google.com/permissions">myaccount.google.com/permissions</a>.
      Stopping calsync and deleting its token file removes its stored
      credentials; events already copied remain in whichever calendar holds them
      until deleted there.</p>
    '';

    "terms.html" = page "Terms" ''
      <p>calsync is a personal tool used only by its operator, Hugo Berendi, with
      his own accounts. It is not offered as a service to anyone else, and no one
      else is permitted to use it.</p>
      <p>It is provided as is, without any warranty. Use of Google services
      through it remains subject to Google's own terms.</p>
    '';
  };
in {
  yomi.cloudflared.at.calsync.port = port;

  # Loopback only; the tunnel is the one way in.
  services.nginx.virtualHosts.calsync = {
    serverName = endpoint.host;
    listen = [
      {
        addr = "127.0.0.1";
        inherit port;
      }
    ];
    root = site;
  };
}
