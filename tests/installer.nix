{pkgs}:
pkgs.runCommand "yomi-installer-checks" {
  nativeBuildInputs = [pkgs.python3 pkgs.bash pkgs.coreutils];
} ''
  python3 ${./installer.py} ${../scripts/live.sh}
  echo 'Installer argument, failure and cleanup checks passed' > "$out"
''
