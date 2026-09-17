# Binary caches for every configured host, read by hosts/nixos/common/nix.nix.
# Plain data rather than a module, so it can be imported outside the module
# system.
#
# flake.nix carries a literal copy of these two lists in its top-level
# `nixConfig`; nix refuses to force a thunk there, so it cannot import this
# file. Change both together.
{
  substituters = [
    "https://nix-community.cachix.org"
    "https://smos.cachix.org"
    "https://intray.cachix.org"
    "https://playit-nixos-module.cachix.org"
    "https://cache.numtide.com"
    "https://nvf.cachix.org"
    "https://hugo-berendi.cachix.org"
  ];

  trustedPublicKeys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "smos.cachix.org-1:YOs/tLEliRoyhx7PnNw36cw2Zvbw5R0ASZaUlpUv+yM="
    "intray.cachix.org-1:qD7I/NQLia2iy6cbzZvFuvn09iuL4AkTmHvjxrQlccQ="
    "playit-nixos-module.cachix.org-1:22hBXWXBbd/7o1cOnh+p0hpFUVk9lPdRLX3p5YSfRz4="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "nvf.cachix.org-1:GMQzlEPrdqVlEzWsdk/6NH9TIoRmFVMZLUfBMvNxzlo="
    "hugo-berendi.cachix.org-1:bUxGkcUJGjKZUDcSu6WvzecShvqbpxM4YvkfcbnAm2Q="
  ];
}
