{
  stdenv,
  fetchFromGitHub,
  pkg-config,
  cmake,
  ninja,
  debug ? false,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "grub-btrfs";
  version = "4.13";

  src = fetchFromGitHub {
    owner = "Antynea";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-BYQF1zM6bJ44ag9FJ0aTSkhOTY9U7uRdp3SmRCs5fJM=";
  };

  cmakeBuildType =
    if debug
    then "Debug"
    else "Release";

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];
})
