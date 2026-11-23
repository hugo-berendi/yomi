# Sources live in ../script-src, outside the directory that cli/default.nix
# symlinks to ~/.config/scripts and puts on PATH, so each of these names comes
# from exactly one place: the package below, with its dependencies declared.
{pkgs, ...}: let
  uptimes = pkgs.writeShellApplication {
    name = "uptimes";
    runtimeInputs = with pkgs; [coreutils openssh gawk util-linux];
    text = builtins.readFile ../script-src/uptimes.sh;
  };

  volume = pkgs.writeShellApplication {
    name = "volume";
    runtimeInputs = with pkgs; [wireplumber playerctl gawk];
    text = builtins.readFile ../script-src/volume.sh;
  };

  backlight = pkgs.writeShellApplication {
    name = "backlight";
    runtimeInputs = with pkgs; [brightnessctl gawk];
    text = builtins.readFile ../script-src/backlight.sh;
  };

  rplc = pkgs.writeShellApplication {
    name = "rplc";
    runtimeInputs = with pkgs; [fd sd];
    text = builtins.readFile ../script-src/rplc.sh;
  };
in {
  home.packages = [uptimes rplc volume backlight];
}
