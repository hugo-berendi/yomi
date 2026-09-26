{
  pkgs,
  upkgs,
  ...
}: {
  imports = [
    ./global.nix
    ./features/desktop/wakatime
  ];
  home = {
    file = {};
    sessionVariables = {EDITOR = "nvim";};
    packages = with pkgs; [
      pay-respects
      sxiv
      # upkgs.unityhub
      # upkgs.nerdfetch # for displaying pc/laptop stats
      upkgs.nh
      upkgs.nix-output-monitor
      upkgs.nvd

      # {{{ Clis
      sops # Secret editing
      # sherlock # Search for usernames across different websites
      # }}}
      # {{{ Media playing/recording
      mpv # Video player
      imv # Image viewer
      # peek # GIF recorder
      # obs-studio # video recorder
      # }}}
    ];
  };

  # {{{ SSH identity
  # inari's own key, authorized on the forges only. It has no passphrase so
  # that unattended sessions here can pull and push; it is deliberately not in
  # hosts/nixos/*/keys/, which would authorize it for login on every host.
  # The old shared key stays as a fallback until it is removed from the forges.
  yomi.pilot.sshIdentity = ["~/.ssh/id_ed25519_inari" "~/.ssh/id_ed25519"];
  # }}}

  yomi.toggles.isServer.enable = true;
}
