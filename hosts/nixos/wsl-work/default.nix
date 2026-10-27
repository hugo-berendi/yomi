# Work laptop, NixOS-WSL instance.
_: {
  imports = [../common/wsl.nix];

  networking.hostName = "wsl-work";
  environment.etc.machine-id.text = "6f1d0c3a9b7e4e25a8c14d52b3e90f17";
}
