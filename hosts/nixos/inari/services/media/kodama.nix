{
  config,
  inputs,
  ...
}: {
  # Weekly, monthly and yearly reviews of what was played in Navidrome, plus
  # the Spotify history from before it; see the kodama repository.
  imports = [inputs.kodama.nixosModules.default];

  # {{{ Reverse proxy
  # LAN and tailnet only, like Navidrome itself.
  yomi.nginx.at.wrapped.port = config.yomi.ports.kodama;
  # }}}
  # {{{ Service
  services.kodama = {
    enable = true;
    settings = {
      listen = "127.0.0.1:${toString config.yomi.ports.kodama}";
      baseURL = "https://${config.yomi.nginx.at.wrapped.host}";
      language = "de";
      # Migadu accepts only the account's own address as sender (msmtp.nix).
      mail.from = "Kodama <no-reply@tengu.hugo-berendi.de>";
    };
    # Covers come from the album folders, which the media group reads.
    extraGroups = ["media"];
    users.hugo = {
      displayName = "Hugo";
      navidromeUser = "hugoberendi";
      email = config.yomi.pilot.email;
      # Audiobooks and podcasts get their own tabs. The radio plays in the
      # Spotify history (Gregs Tagebuch, Tschick, Die drei ???) are found by
      # their numbered chapters; ASMR is none of music, book or podcast.
      exclude = {
        genres = ["*asmr*"];
        artists = ["*asmr*"];
      };
      audiobookshelf.tokenFile = config.sops.secrets.kodama_audiobookshelf_token.path;
    };
  };
  # An API key of the pilot's Audiobookshelf account; it reads their
  # listening sessions. Only kodama-sync gets it, as a credential.
  sops.secrets.kodama_audiobookshelf_token.sopsFile = ../../secrets.yaml;
  # }}}
  # {{{ Persistence and backups
  yomi.persistence.at.state.apps.kodama.directories = [
    {
      directory = "/var/lib/kodama";
      user = "kodama";
      group = "kodama";
      mode = "0750";
    }
  ];
  # Navidrome deletes a file's play history with the file, and Spotify's
  # export takes a month to request again: kodama's database is the only
  # complete copy of the listening history, so it goes off-site too.
  yomi.restic.offsite.paths = ["/persist/state/var/lib/kodama"];
  # }}}
}
