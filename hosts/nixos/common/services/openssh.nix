# This setups a SSH server.
{
  outputs,
  config,
  lib,
  ...
}: let
  # Record containing all the hosts
  hosts = outputs.nixosConfigurations;

  # Name of the current hostname
  hostname = config.networking.hostName;

  # Function from hostname to relative path to public ssh key
  pubKey = host: ../../${host}/keys/ssh_host_ed25519_key.pub;
in {
  services.openssh = {
    enable = true;

    settings = {
      PermitRootLogin = lib.mkForce "no"; # Forbid root login through SSH.
      # Keys only. This said "Use keys only" next to a value of `true` for as
      # long as it has existed.
      #
      # Turning off PasswordAuthentication on its own does not achieve that:
      # sshd still offers keyboard-interactive, UsePAM backs it with pam_unix,
      # and a password prompt comes straight back. Both have to go.
      PasswordAuthentication = lib.mkDefault false;
      KbdInteractiveAuthentication = lib.mkDefault false;
    };

    # Automatically remove stale sockets
    extraConfig = ''
      StreamLocalBindUnlink yes
    '';

    # Generate ssh key
    hostKeys = let
      mkKey = type: path: extra:
        {inherit type path;} // extra;
    in [
      (mkKey "ed25519" "/persist/state/etc/ssh/ssh_host_ed25519_key" {})
      (mkKey "rsa" "/persist/state/etc/ssh/ssh_host_rsa_key" {bits = 4096;})
    ];
  };

  # A host with no committed public key is dropped from knownHosts below rather
  # than breaking the build, so the pin can go missing without anything saying
  # so. Both desktops spent two years pinned to a copy of the pilot's *user*
  # key, which no sshd will ever present, and the resulting mismatch is only
  # visible at connect time.
  warnings = let
    unpinned = lib.filter (name: !builtins.pathExists (pubKey name)) (builtins.attrNames hosts);
  in
    lib.optional (unpinned != []) ''
      No ssh host key is pinned for: ${lib.concatStringsSep ", " unpinned}.
      Connections to these hosts fall back to trust-on-first-use.
      Capture the real key once the host is reachable: `just import-host-key <host>`.
    '';

  # Add each host in this repo to the knownHosts list
  programs.ssh = {
    knownHosts = lib.pipe hosts [
      # attrsetof host -> attrsetof { ... }
      (
        builtins.mapAttrs
        # string -> host -> { ... }
        (
          name: _: {
            publicKeyFile = pubKey name;
            extraHostNames = lib.optional (name == hostname) "localhost";
          }
        )
      )

      # attrsetof { ... } -> attrsetof { ... }
      (
        lib.attrsets.filterAttrs
        # string -> { ... } -> bool
        (_: {publicKeyFile, ...}: builtins.pathExists publicKeyFile)
      )
    ];
  };

  # By default, this will ban failed ssh attempts
  services.fail2ban.enable = true;

  # Makes it easy to copy host keys at install time without messing up permissions
  systemd.tmpfiles.rules =
    [
      "d /persist/state/etc/ssh"
    ]
    ++ (lib.lists.forEach config.services.openssh.hostKeys (key: "e ${key.path} 0700"));
}
