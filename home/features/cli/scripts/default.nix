{pkgs, ...}: let
  uptimes = pkgs.writeShellScriptBin "uptimes" (builtins.readFile ./uptimes.sh);

  volume = pkgs.writeShellScriptBin "volume" (builtins.readFile ./volume.sh);

  backlight = pkgs.writeShellScriptBin "backlight" (builtins.readFile ./backlight.sh);

  rplc =
    pkgs.writeShellScriptBin "rplc"
    /*
    bash
    */
    ''
      #!/usr/bin/env bash

      # Check if enough arguments are passed
      if [ "$#" -lt 2 ]; then
        echo "Usage: $0 <search-pattern> <replace-pattern> [directory]"
        exit 1
      fi

      # Assign arguments to variables
      search=$1
      replace=$2

      # Manually set the directory or use current directory
      if [ -z "$3" ]; then
        dir="."
      else
        dir=$3
      fi

      # Use fd and sd to replace text
      fd -t f "$dir" -x sd "$search" "$replace" {}
    '';
in {
  home.packages = [uptimes rplc volume backlight];
}
