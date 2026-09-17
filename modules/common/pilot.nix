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
    githubUser = lib.mkOption {
      type = lib.types.str;
      default = "hugo-berende";
      description = "GitHub username for git and gh CLI";
    };
    signingKey = lib.mkOption {
      type = lib.types.str;
      default = "~/.ssh/id_ed25519.pub";
      description = ''
        Path to the SSH public key git signs with.

        Was ~/.ssh/yubikey.pub, which no longer exists on any host, so every
        `git tag` failed with "Couldn't load public key" -- tag.gpgsign is on
        even though commit.gpgsign is not. The pilot's own key signs fine; it
        is passphrase-protected, so it needs to be in the agent.
      '';
    };
    gpgKeygrip = lib.mkOption {
      type = lib.types.str;
      default = "67D63C5F40CC55DA";
      description = "GPG keygrip for gpg-agent SSH support";
    };
    sshIdentity = lib.mkOption {
      type = lib.types.str;
      default = "~/.ssh/id_ed25519";
      description = "Path to SSH identity file";
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
