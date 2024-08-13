{
  programs.fish.loginShellInit = ''
    set PASSWORD_STORE_ENABLE_EXTENSIONS true
    set PASSWORD_STORE_EXTENSIONS_DIR (nix-store --query --requisites /run/current-system | grep pass-env)/lib/password-store/extensions
  '';
}
