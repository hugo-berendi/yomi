{
  config,
  lib,
  pkgs,
  ...
}: let
  package = "com.badbeans.DarkIdle";
  dataDir = "/persist/state/var/lib/immortal-rising";
  adbPort = config.yomi.ports.redroid-adb;
  serial = "127.0.0.1:${toString adbPort}";
  alertUrl = "http://127.0.0.1:${toString config.yomi.ports.n8n-alert-router}/alert";

  python = pkgs.python3.withPackages (ps: [ps.opencv4 ps.numpy]);

  immortal-rising = pkgs.writeShellApplication {
    name = "immortal-rising";
    runtimeInputs = with pkgs; [android-tools apkeep coreutils curl docker gnugrep gnused jq systemd unzip];
    text = ''
      export ANDROID_USER_HOME=${dataDir}/android
      serial=${serial}
      workdir=${dataDir}/agent

      alert() { # severity title message resolved
        jq -n --arg s "$1" --arg t "$2" --arg m "$3" --argjson r "$4" \
          '{source: "immortal-rising", severity: $s, title: $t, message: $m, resolved: $r, fingerprint: "immortal-rising"}' \
          | curl -sf --max-time 15 -X POST -H 'content-type: application/json' -d @- ${alertUrl} >/dev/null || true
      }

      up() {
        systemctl start docker-redroid.service
        for _ in $(seq 1 60); do
          adb connect "$serial" >/dev/null 2>&1 || true
          [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && return 0
          sleep 5
        done
        echo "redroid did not finish booting" >&2
        return 1
      }

      down() {
        adb disconnect "$serial" >/dev/null 2>&1 || true
        systemctl stop docker-redroid.service
      }

      # APKPure serves the same builds as Google Play but needs no account.
      # The game ships as a base split, an arm64 split and an asset pack, so a
      # plain `adb install` of one file would not start it.
      update() {
        latest=$(apkeep -l -a ${package} 2>&1 | grep '^|' | tr -d '| ' | tr ',' '\n' | sort -V | tail -n1)
        installed=$(adb -s "$serial" shell dumpsys package ${package} | sed -n 's/^ *versionName=//p' | head -n1 | tr -d '\r')
        [ -n "$latest" ] || { echo "could not list versions" >&2; return 1; }
        if [ -n "$installed" ] && [ "$(printf '%s\n%s\n' "$installed" "$latest" | sort -V | tail -n1)" = "$installed" ]; then
          echo "up to date at $installed"
          return 0
        fi
        scratch=$(mktemp -d)
        trap 'rm -rf "$scratch"' RETURN
        (
          cd "$scratch"
          apkeep -a "${package}@$latest" .
          unzip -q -d apks ./*.xapk '*.apk'
          adb -s "$serial" install-multiple -r apks/*.apk
        )
        echo "updated ''${installed:-none} -> $latest"
      }

      agent() {
        ${python}/bin/python -I ${./agent.py} "$1" --serial "$serial" --package ${package} --workdir "$workdir"
      }

      case "''${1:-}" in
        up) up ;;
        down) down ;;
        shot) agent shot ;;
        update) update ;;
        run)
          trap down EXIT
          up
          update
          status=0
          agent run || status=$?
          case $status in
            0) alert info "Daily tasks done" "" true ;;
            3) alert info "Not configured yet" "Capture templates with immortal-rising shot and write ${dataDir}/agent/flow.json." false ;;
            *) alert warning "Daily tasks failed" "See journalctl -u immortal-rising and ${dataDir}/agent/last-failure.png." false ;;
          esac
          exit $status
          ;;
        *) echo "usage: immortal-rising up|down|shot|update|run" >&2; exit 2 ;;
      esac
    '';
  };
in {
  environment.systemPackages = [immortal-rising];

  # {{{ Storage
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0700 0 0 - -"
    "d ${dataDir}/data 0700 0 0 - -"
    "d ${dataDir}/android 0700 0 0 - -"
    "d ${dataDir}/agent 0700 0 0 - -"
    "d ${dataDir}/agent/templates 0700 0 0 - -"
    "d ${dataDir}/agent/shots 0700 0 0 - -"
  ];
  # }}}
  # {{{ Container
  # Started by the daily unit, not at boot: Android idles at a few GB of RAM
  # and the game is only played for a few minutes a day. /data is kept, so the
  # Facebook session that a human logged in once survives each stop.
  #
  # The image is a tag, not a digest, until the first test run has confirmed
  # that its libndk_translation runs the arm64-only game (the build has no x86
  # libraries). If it does not, build an image with ayasa520/redroid-script.
  virtualisation.oci-containers.containers.redroid = {
    image = "redroid/redroid:13.0.0-latest";
    autoStart = false;
    # Loopback only: an open adb port is a root shell on the container.
    ports = ["127.0.0.1:${toString adbPort}:5555"];
    volumes = ["${dataDir}/data:/data"];
    cmd = [
      "androidboot.redroid_width=720"
      "androidboot.redroid_height=1280"
      "androidboot.redroid_dpi=320"
      "androidboot.redroid_gpu_mode=guest"
      # abilist32 must stay non-empty: with only 64-bit entries zygote_secondary
      # aborts ("Unable to determine ABI list") and Android boot-loops without
      # ever starting system_server.
      "ro.product.cpu.abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi"
      "ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi"
      "ro.product.cpu.abilist64=x86_64,arm64-v8a"
      "ro.dalvik.vm.isa.arm=x86"
      "ro.dalvik.vm.isa.arm64=x86_64"
      "ro.enable.native.bridge.exec=1"
      "ro.dalvik.vm.native.bridge=libndk_translation.so"
    ];
    log-driver = "journald";
    # redroid needs --privileged for binder and its own mounts.
    extraOptions = ["--privileged" "--memory=6g" "--stop-timeout=30"];
  };
  # }}}
  # {{{ Daily run
  systemd.services.immortal-rising = {
    description = "Update Immortal Rising and play the daily tasks";
    after = ["docker.service" "network-online.target"];
    requires = ["docker.service"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe immortal-rising} run";
      # Cold Android boot, a possible 600 MB update download, then the flow.
      TimeoutStartSec = "45min";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ReadWritePaths = [dataDir];
    };
  };

  # The phone is signed out whenever the emulator logs in again, so this runs
  # once a day at a time the owner is not playing.
  systemd.timers.immortal-rising = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 17:30:00";
      Persistent = true;
    };
  };
  # }}}
}
