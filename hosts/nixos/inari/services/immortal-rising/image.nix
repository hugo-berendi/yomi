{pkgs}: let
  # The stock image's libndk_translation runs Unity 6 (6000.3) il2cpp arm64
  # builds only as far as an allocation of -4.6 GB ("System out of memory",
  # SystemInfo reports Cores = 1), so Immortal Rising aborts on startup.
  # Houdini is the other translator. Both archives are what
  # github.com/ayasa520/redroid-script downloads for Android 13, pinned by hash
  # instead of by that script's MD5.
  base = pkgs.dockerTools.pullImage {
    imageName = "redroid/redroid";
    imageDigest = "sha256:41e5f0c1ff27a4a474c474e5595168cedf6c40fc5dd102c5617f48c80f511e9e";
    hash = "sha256-xvD3vT4ZYarQtmgyAzSeTOFXm+6mQgjpJTLtu4rc6DU=";
    finalImageName = "redroid/redroid";
    finalImageTag = "13.0.0-latest";
  };

  houdini = pkgs.fetchzip {
    url = "https://github.com/rote66/vendor_intel_proprietary_houdini/archive/0c149b1e14d7bfd4b2af261afc6f2e80517dbd98.zip";
    hash = "sha256-VO5AMso0dCaHxAwrIf4mT5seaR3yqrZkJ5NjxJrTtCw=";
  };

  # Replaces the image's init.rc and ld.config with versions that register the
  # binfmt handlers; without them the kernel would not hand ARM code to houdini.
  hack = pkgs.fetchzip {
    url = "https://github.com/rote66/redroid_libhoudini_hack/archive/a2194c5e294cbbfdfe87e51eb9eddb4c3621d8c3.zip";
    hash = "sha256-+1KHAzL3IFl1yg6K4K6sxPrKS27BoU3rxBSprqk0wp0=";
  };

  layer = pkgs.runCommand "redroid-houdini-layer" {} ''
    mkdir -p $out/system
    cp -r ${houdini}/prebuilts/. $out/system/
    chmod -R u+w $out
    cp -r ${hack}/13.0.0/. $out/system/
    chmod -R u+w $out
    install -D -m 0644 ${./houdini.rc} $out/system/etc/init/houdini.rc
  '';
in
  pkgs.dockerTools.buildImage {
    name = "redroid-houdini";
    tag = "13.0.0";
    fromImage = base;
    copyToRoot = layer;
  }
