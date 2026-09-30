{
  pkgs,
  config,
}: let
  run = pkgs.writeShellScript "online-stable-cpus-test" (builtins.replaceStrings ["/sys/devices/system/cpu"] ["$TMPDIR/cpus"] config.systemd.services.online-stable-cpus.script);
in
  pkgs.runCommand "yomi-inari-cpu-checks" {} ''
    mkdir -p "$TMPDIR/cpus"
    for cpu in {1..11}; do
      mkdir -p "$TMPDIR/cpus/cpu$cpu"
      echo 0 > "$TMPDIR/cpus/cpu$cpu/online"
    done
    # Reproduce the current boot's topology, including the suspect CPU 4.
    for cpu in 2 4 6 7 8 9 10 11; do
      echo 1 > "$TMPDIR/cpus/cpu$cpu/online"
    done
    ${run}
    for cpu in 4 5; do
      test "$(cat "$TMPDIR/cpus/cpu$cpu/online")" = 0
    done
    for cpu in 1 2 3 6 7 8 9 10 11; do
      test "$(cat "$TMPDIR/cpus/cpu$cpu/online")" = 1
    done
    # Already-correct state must converge to the same result.
    ${run}
    test ${pkgs.lib.escapeShellArg (builtins.toJSON (builtins.filter (p: pkgs.lib.hasPrefix "maxcpus=" p) config.boot.kernelParams))} = '["maxcpus=1"]'
    test ${pkgs.lib.escapeShellArg (builtins.toJSON (builtins.filter (p: pkgs.lib.hasPrefix "maxcpus=" p) config.specialisation.rescue.configuration.boot.kernelParams))} = '["maxcpus=1"]'
    test ${pkgs.lib.boolToString config.specialisation.rescue.configuration.systemd.services.online-stable-cpus.enable} = false
    # Missing hotplug controls must fail instead of silently claiming success.
    rm "$TMPDIR/cpus/cpu4/online"
    if ${run}; then
      echo "Missing CPU control was ignored" >&2
      exit 1
    fi
    echo 'CPU containment and rescue checks passed' > "$out"
  ''
