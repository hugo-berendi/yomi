_: {
  # Pulls main over anonymous HTTPS so root needs no ssh key. main only
  # receives the update PRs after `just lint`/`just check` and the update gate pass,
  # and a failed build leaves the running generation untouched.
  # `switch` rather than `boot`: t3code and its providers only change when the
  # new generation is live. A switch restarts t3code-web, which ends running turns.
  system.autoUpgrade = {
    enable = true;
    flake = "git+https://git.hugo-berendi.de/hugo-berendi/yomi.git?ref=main#inari";
    operation = "switch";
    dates = "04:00";
    randomizedDelaySec = "0";
    persistent = true;
    allowReboot = false;
  };
}
