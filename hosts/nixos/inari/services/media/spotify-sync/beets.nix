# Metadata: every candidate from MusicBrainz and Deezer is scored against
# the file, and the closest wins. Below the threshold the file keeps its
# own tags (quiet_fallback: asis), so an unsure match never overwrites good
# tags with wrong ones.
#
# Spotify is left out here. Every search candidate costs it two single-item
# requests, and the backfill's few thousand got this app locked out of
# them for 17 hours on 2026-11-15 (429, Retry-After 60517), the app
# sockseek needs too. beets-spotify.yaml adds it back for songs sockseek
# reported a Spotify track for: two requests each, and the only source
# that also names a single song's album.
{
  musicDir,
  stateDir,
}: {
  directory = musicDir;
  library = "${stateDir}/beets/library.db";
  # versionguard: see beets-plugins/versionguard.py.
  pluginpath = [
    "${builtins.path {
      path = ./beets-plugins;
      name = "beets-plugins";
    }}"
  ];
  plugins = ["musicbrainz" "deezer" "versionguard" "fetchart" "embedart" "lyrics" "lastgenre"];
  ui.color = false;
  import = {
    # Tags only: files stay where sockseek put them, because its
    # indexes and the .m3u playlists point at those paths.
    write = true;
    copy = false;
    move = false;
    resume = false;
    incremental = false;
    quiet_fallback = "asis";
    duplicate_action = "keep";
    log = "${stateDir}/beets/import.log";
  };
  match = {
    # beets' default (0.04) only trusts near-perfect matches. A correct
    # album still scores around 0.1 when the uploader's folder lacks a
    # bonus track or the release country differs; 0.15 accepts those
    # and still rejects other albums, which scored 0.4 and up in tests.
    strong_rec_thresh = 0.15;
    # A file's leftover IDs from another release (often a compilation)
    # would otherwise outweigh title, artist and length, and sink even
    # the exact Spotify track a song was downloaded for.
    distance_weights.track_id = 0.0;
    preferred = {
      countries = ["DE" "XW"];
      media = ["Digital Media|File"];
    };
  };
  # beets adds 0.5 to any candidate not from MusicBrainz by default,
  # which made Spotify and Deezer lose even with identical data.
  musicbrainz.data_source_mismatch_penalty = 0.0;
  deezer.data_source_mismatch_penalty = 0.0;
  fetchart = {
    auto = true;
    minwidth = 500;
    maxwidth = 1500;
    # The uploader's own scan first, when it is big enough; then the
    # cover of the release beets matched: the Cover Art Archive for a
    # MusicBrainz match, the Deezer album's own cover (cover_art_url) for a
    # Deezer match. "spotify" reads the public album page, not the API.
    # No "itunes": without an exact hit it takes the first search result,
    # and on 2026-11-16 put Maroon 5's "Girls Like You" on Juju's "44 ME",
    # which iTunes does not carry.
    sources = ["filesystem" "coverart" "cover_art_url" "spotify"];
  };
  embedart.auto = true;
  # Synced lyrics from LRCLIB; Navidrome shows them line by line.
  lyrics = {
    auto = true;
    synced = true;
    sources = ["lrclib"];
  };
  lastgenre = {
    auto = true;
    count = 3;
    separator = "; ";
  };
}
