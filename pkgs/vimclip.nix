{
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  wl-clipboard,
  xsel,
}:
stdenv.mkDerivation {
  pname = "vimclip";
  version = "0-unstable-2023-06-02";

  src = fetchFromGitHub {
    owner = "hrantzsch";
    repo = "vimclip";
    rev = "52003cc31e6e1d20550cdf6b7d3bf1a019a34fa0";
    hash = "sha256-7/Dfc+3RGxBb4lLlXV5N02Q6ubvO9HBf+siv7VSM2sU=";
  };

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall
    install -Dm755 vimclip $out/bin/.vimclip-unwrapped
    makeWrapper $out/bin/.vimclip-unwrapped $out/bin/vimclip \
      --run '
        if [ "wayland" = "$XDG_SESSION_TYPE" ]; then
          export VIMCLIP_CLIPBOARD_COMMAND=${wl-clipboard}/bin/wl-copy
        else
          export VIMCLIP_CLIPBOARD_COMMAND=${xsel}/bin/xsel
        fi
      '
    runHook postInstall
  '';

  meta.mainProgram = "vimclip";
}
