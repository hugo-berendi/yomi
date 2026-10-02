{pkgs}:
pkgs.runCommand "yomi-recover-unit-tests" {
  nativeBuildInputs = [pkgs.python3 pkgs.age pkgs.zstd];
} ''
  python3 ${./recover-tool.py} ${../pkgs/yomi-recover/recover.py}
  touch "$out"
''
