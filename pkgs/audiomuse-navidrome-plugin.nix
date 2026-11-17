# Navidrome plugin that answers "similar songs" and "similar artists" from
# AudioMuse-AI's analysis of the music itself; see
# hosts/nixos/inari/services/media/audiomuse.nix.
{
  lib,
  buildNavidromePlugin,
  fetchFromGitHub,
}:
buildNavidromePlugin rec {
  # The .ndp file is named after pname; Navidrome takes the plugin's id from
  # its manifest.
  pname = "audiomuseai";
  version = "12";

  src = fetchFromGitHub {
    owner = "NeptuneHub";
    repo = "AudioMuse-AI-NV-plugin";
    tag = "v${version}";
    hash = "sha256-T+41xeeX4ioz8320cM4ccdjVoORX68cKX1U7jpAB5ao=";
  };

  vendorHash = "sha256-mXes+doBSa5kcfHp1cuzTz30wnyyPN7NLC0iOSL8FDo=";

  meta = {
    description = "AudioMuse-AI instant mix and artist radio for Navidrome";
    homepage = "https://github.com/NeptuneHub/AudioMuse-AI-NV-plugin";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [fromSource];
  };
}
