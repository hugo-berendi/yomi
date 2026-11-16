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
      # Not music. Spotify's export has no genres, so its audiobooks and
      # radio plays go by artist; these topped whole years of it.
      exclude = {
        genres = ["*asmr*" "Hörbuch" "Hörbücher" "Hörspiel" "Audiobook" "Podcast"];
        artists = [
          "*asmr*"
          "Gregs Tagebuch"
          "Jeff Kinney"
          "Wolfgang Herrndorf"
          "LEGO Ninjago"
          "Erebos"
          "Niklas Kolorz"
          "Die drei ???"
        ];
        albums = ["*hörspiel*" "*hörbuch*"];
      };
    };
  };
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
