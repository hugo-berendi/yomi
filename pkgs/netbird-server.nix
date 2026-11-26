# NetBird's combined server: management, signal, relay and STUN in one
# process, the layout NetBird's own setup uses since 0.65. nixpkgs builds the
# components one by one; this builds `combined/` from the same source and
# vendor hash, so it follows nixpkgs' netbird version.
{netbird-relay}:
netbird-relay.overrideAttrs (old: {
  pname = "netbird-server";
  subPackages = ["combined"];
  postInstall = ''
    mv $out/bin/combined $out/bin/netbird-server
  '';
  meta =
    old.meta
    // {
      description = "NetBird management, signal, relay and STUN server in one process";
      mainProgram = "netbird-server";
    };
})
