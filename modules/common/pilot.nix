{lib, ...}: {
  options.yomi.pilot = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "hugob";
      description = "The name of the main user for this machine";
    };
    email = lib.mkOption {
      type = lib.types.str;
      default = "personal@hugo-berendi.de";
      description = "Primary email address for the pilot user";
    };
    gitEmail = lib.mkOption {
      type = lib.types.str;
      default = "git@hugo-berendi.de";
      description = ''
        Address git commits and tags are made with. It is the one verified on
        the GitHub and Forgejo accounts, so the forges attribute commits to
        them only with this, and GitHub marks signatures verified only when a
        key's user ID carries it.
      '';
    };
    githubUser = lib.mkOption {
      type = lib.types.str;
      default = "hugo-berendi";
      description = "GitHub username for git and gh CLI";
    };
    gpgKey = lib.mkOption {
      type = lib.types.str;
      default = "0E0F00D0D176B857A972E4D8ABC3ACDB6348CD34";
      description = ''
        Fingerprint of the pilot's OpenPGP key, which git and mail sign with.
        Its primary key is offline on kagutsuchi; the signing, encryption and
        authentication subkeys live only on the YubiKey (serial 30636315), so
        signing works only where that card is plugged in. The public key is
        home/features/cli/pilot.asc.

        It replaces 67D63C5F40CC55DA (rsa4096, 2024), revoked on 2026-09-26.
        That ID sat here as "gpgKeygrip", though it was a key ID.
      '';
    };
    sshIdentity = lib.mkOption {
      type = with lib.types; coercedTo str lib.singleton (listOf str);
      default = ["~/.ssh/id_ed25519"];
      description = ''
        SSH identity files, tried in order. Missing files are skipped by ssh,
        so a fallback can stay listed while a key is being rolled over.
      '';
    };
  };

  options.yomi.location = {
    latitude = lib.mkOption {
      type = lib.types.str;
      default = "51.23";
      description = "Latitude for location-based services";
    };
    longitude = lib.mkOption {
      type = lib.types.str;
      default = "14.83";
      description = "Longitude for location-based services";
    };
  };
}
