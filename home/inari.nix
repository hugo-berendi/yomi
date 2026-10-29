{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./global.nix
    ./features/desktop/wakatime
  ];
  home = {
    packages = with pkgs; [
      # upkgs.unityhub
      # upkgs.nerdfetch # for displaying pc/laptop stats

      # {{{ Clis
      # sherlock # Search for usernames across different websites
      # }}}
      # {{{ Media playing/recording
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

  # {{{ SSH config as a real file
  # t3code runs in a bwrap user namespace that maps only the pilot's uid, so
  # every /nix/store file looks owned by nobody there. ssh refuses a
  # ~/.ssh/config that is a store symlink ("Bad owner or permissions"), which
  # broke `git fetch origin` and any bare `ssh` run by an agent. Replace the
  # link with a copy the pilot owns; `force` lets home-manager take it back
  # on the next generation, and the activation step copies it out again.
  home.file.".ssh/config".force = true;
  home.activation.sshConfigOwnedCopy = lib.hm.dag.entryAfter ["linkGeneration"] ''
    config=${lib.escapeShellArg "${config.home.homeDirectory}/.ssh/config"}
    if [ -L "$config" ]; then
      run install -m 600 "$(readlink -f "$config")" "$config"
    fi
  '';
  # }}}
}
