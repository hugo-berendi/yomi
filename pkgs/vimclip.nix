{
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  wl-clipboard,
  xsel,
}:
stdenv.mkDerivation {
  pname = "vimclip";
  version = "1.0.0-unstable-2024-12-15";

  src = fetchFromGitHub {
    owner = "hrantzsch";
    repo = "vimclip";
    rev = "5a6811feabaf85ae0f527716678c51972c8e5add";
    hash = "sha256-2lrhoEE1auXuqseNYihksNJtzkXdgEla6n8ILEwpVLA=";
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
