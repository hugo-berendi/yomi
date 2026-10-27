# Home PC. The hardware runs Windows; this is the NixOS-WSL instance on it.
_: {
  imports = [../common/wsl.nix];

  networking.hostName = "tsukuyomi";
  # Carried over from the previous single `wsl` host, which lived on this PC.
  environment.etc.machine-id.text = "08357db3540c4cd2b76d4bb7f825ec89";
}
