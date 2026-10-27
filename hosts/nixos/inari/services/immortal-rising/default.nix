{
  config,
  lib,
  pkgs,
  ...
}: let
  package = "com.badbeans.DarkIdle";
  dataDir = "/persist/state/var/lib/immortal-rising";
  # Android's /data lives on ext4 inside an image on the HDD pool: see the
  # Storage section for why it can be neither ZFS nor the NVMe.
  imageDir = "/raid5pool/immortal-rising";
  adbPort = config.yomi.ports.redroid-adb;
  serial = "127.0.0.1:${toString adbPort}";
  alertUrl = "http://127.0.0.1:${toString config.yomi.ports.n8n-alert-router}/alert";

  python = pkgs.python3.withPackages (ps: [ps.opencv4 ps.numpy]);

  immortal-rising = pkgs.writeShellApplication {
    name = "immortal-rising";
    runtimeInputs = with pkgs; [android-tools apkeep coreutils curl docker gnugrep gnused jq systemd unzip util-linux];
    text = ''
      export ANDROID_USER_HOME=${dataDir}/android
      serial=${serial}
      workdir=${dataDir}/agent

      alert() { # severity title message resolved fingerprint
        jq -n --arg s "$1" --arg t "$2" --arg m "$3" --argjson r "$4" --arg f "immortal-rising-$5" \
          '{source: "immortal-rising", severity: $s, title: $t, message: $m, resolved: $r, fingerprint: $f}' \
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

      # The game runs around the clock, so the screen must never sleep. The
      # settings persist in /data, but reapplying them is cheap.
      awake() {
        adb -s "$serial" shell svc power stayon true
        adb -s "$serial" shell input keyevent KEYCODE_WAKEUP
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
        ${python}/bin/python -I ${./agent.py} "$1" --serial "$serial" --package ${package} --workdir "$workdir" "''${@:2}"
      }

      case "''${1:-}" in
        up) up; awake ;;
        view)
          up
          awake
          systemctl start immortal-rising-view.service
          echo "open http://$(hostname):${toString config.yomi.ports.immortal-rising-view}/ over Tailscale"
          ;;
        down) adb disconnect "$serial" >/dev/null 2>&1 || true; systemctl stop docker-redroid.service ;;
        shot) agent shot ;;
        update) up; update ;;
        run)
          routine=''${2:?usage: immortal-rising run <daily|periodic>}
          # One routine at a time: two of them tapping the same screen would
          # undo each other.
          exec 9>${dataDir}/lock
          flock -w 1500 9
          up
          awake
          [ "$routine" = daily ] && update
          status=0
          agent run --routine "$routine" || status=$?
          case $status in
            0) alert info "$routine tasks done" "" true "$routine" ;;
            3) alert info "Not configured yet" "Capture templates with immortal-rising shot and write ${dataDir}/agent/flow.json." false "$routine" ;;
            # Another device holds the account. That is a choice, not a fault.
            4) status=0 ;;
            *) alert warning "$routine tasks failed" "See journalctl -u immortal-rising-$routine and ${dataDir}/agent/last-failure.png." false "$routine" ;;
          esac
          exit $status
          ;;
        *) echo "usage: immortal-rising up|view|down|shot|update|run <routine>" >&2; exit 2 ;;
      esac
    '';
  };

  routineService = routine: description: {
    inherit description;
    after = ["docker.service" "network-online.target"];
    requires = ["docker.service"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe immortal-rising} run ${routine}";
      # Waiting for the other routine's lock, a possible 600 MB update, then
      # the flow itself.
      TimeoutStartSec = "45min";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ReadWritePaths = [dataDir];
    };
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
    "d ${imageDir} 0700 0 0 - -"
  ];
  # }}}
  # {{{ Container
  # Runs all the time: the game farms while nobody is looking.
  #
  # /data is an ext4 loop image, not a directory on ZFS. On ZFS Android cannot
  # create its app directories (`ls /data/user_de/0` fails with EINVAL, every
  # system app then crashes on "Directory .../databases doesn't exist", and
  # RescueParty restarts the framework forever). The image is on raid5pool
  # because Android writes continuously and the NVMe is near its endurance
  # rating. Losing it costs only the Facebook login; the account is online.
  #
  # The image is the stock redroid 13 plus houdini (see image.nix). The game is
  # arm64-only, and the stock libndk_translation crashes its Unity runtime.
  virtualisation.oci-containers.containers.redroid = {
    image = "redroid-houdini:13.0.0";
    imageFile = import ./image.nix {inherit pkgs;};
    autoStart = true;
    # Loopback only: an open adb port is a root shell on the container.
    ports = ["127.0.0.1:${toString adbPort}:5555"];
    volumes = ["${dataDir}/data:/data"];
    cmd = [
      "androidboot.redroid_width=720"
      "androidboot.redroid_height=1280"
      "androidboot.redroid_dpi=320"
      # Rendering is on the CPU; a low frame rate keeps 24/7 cost down.
      "androidboot.redroid_gpu_mode=guest"
      "androidboot.redroid_fps=20"
      # abilist32 must stay non-empty: with only 64-bit entries zygote_secondary
      # aborts ("Unable to determine ABI list") and Android boot-loops without
      # ever starting system_server.
      "ro.product.cpu.abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi"
      "ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi"
      "ro.product.cpu.abilist64=x86_64,arm64-v8a"
      "ro.dalvik.vm.isa.arm=x86"
      "ro.dalvik.vm.isa.arm64=x86_64"
      "ro.enable.native.bridge.exec=1"
      "ro.enable.native.bridge.exec64=1"
      "ro.dalvik.vm.native.bridge=libhoudini.so"
    ];
    log-driver = "journald";
    # redroid needs --privileged for binder and its own mounts.
    extraOptions = ["--privileged" "--memory=6g" "--cpus=4" "--stop-timeout=30"];
  };

  systemd.services.docker-redroid = {
    path = with pkgs; [e2fsprogs util-linux coreutils];
    preStart = ''
      # Without the mount Android would write into the ZFS directory and
      # boot-loop, so a failure here must stop the unit.
      if [ ! -e ${imageDir}/data.img ]; then
        truncate -s 24G ${imageDir}/data.img
        mkfs.ext4 -q -L redroid-data ${imageDir}/data.img
      fi
      mountpoint -q ${dataDir}/data \
        || mount -o loop,noatime,commit=120 ${imageDir}/data.img ${dataDir}/data
    '';
    postStop = "umount ${dataDir}/data || true";
    after = ["zfs-mount.service"];
    unitConfig.RequiresMountsFor = [imageDir];
  };
  # }}}
  # {{{ Browser remote
  # For logging in to Facebook from a device that cannot run scrcpy. Control of
  # the screen is control of the account, so it is not started at boot, stops
  # with the container, and its port is only reachable through the tailscale0
  # rule in the input chain: no LAN exposure grant is declared for it.
  systemd.services.immortal-rising-view = {
    description = "Browser remote for the Immortal Rising emulator";
    bindsTo = ["docker-redroid.service"];
    after = ["docker-redroid.service"];
    path = [pkgs.android-tools];
    environment.ANDROID_USER_HOME = "/var/lib/immortal-rising-view";
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -I ${./view.py} --serial ${serial} --port ${toString config.yomi.ports.immortal-rising-view}";
      DynamicUser = true;
      StateDirectory = "immortal-rising-view";
      Restart = "on-failure";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
  # }}}
  # {{{ Routines
  # daily: update, quests, quick battles, shop. periodic: bosses, upgrades,
  # dungeons, and otherwise just keeping the session alive. Both are defined by
  # flow.json, which is written once templates have been captured.
  systemd.services.immortal-rising-daily = routineService "daily" "Update Immortal Rising and play the daily tasks";
  systemd.services.immortal-rising-periodic = routineService "periodic" "Keep Immortal Rising farming";

  systemd.timers.immortal-rising-daily = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 17:30:00";
      Persistent = true;
    };
  };

  systemd.timers.immortal-rising-periodic = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitInactiveSec = "15min";
    };
  };
  # }}}
}
