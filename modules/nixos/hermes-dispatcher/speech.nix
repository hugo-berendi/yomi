# Local German text-to-speech for Ciel's voice replies: Piper plus ffmpeg, no network at run time.
{pkgs}: let
  revision = "cf910fb59f1d79ab3b625a63993a108751c6c25d";
  file = name: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/${revision}/de/de_DE/kerstin/low/${name}";
      inherit hash;
    };
  # Piper wants the model and its JSON side by side under one basename. A
  # pinned directory also keeps the voice from being fetched on first use,
  # which the gateway sandbox could not do anyway.
  # Kerstin (low): a female German voice, as Hugo asked. Thorsten (high) was the
  # first pick and is a male speaker, so it went. Of the free female Piper
  # voices, Kerstin and Ramona are the usable ones (Eva K is x_low). On one
  # test sentence Whisper-base recognised Kerstin's output nearly in full and
  # Ramona's badly garbled; median pitch was 167 Hz (Kerstin), 213 Hz (Ramona),
  # 139 Hz (Thorsten). Only a listening test can judge naturalness. Another
  # Piper voice only changes this block.
  voice = pkgs.linkFarm "piper-de-kerstin-low-${builtins.substring 0 7 revision}" [
    {
      name = "de_DE-kerstin-low.onnx";
      path = file "de_DE-kerstin-low.onnx" "sha256-01KnZBiSzr8pA4Wa+U6bqBoUERAhX+OUO82n99pAG3o=";
    }
    {
      name = "de_DE-kerstin-low.onnx.json";
      path = file "de_DE-kerstin-low.onnx.json" "sha256-VucIVWt7m3pTxPiVfgIUIeafEaYAliu6VUz/vnLPLUc=";
    }
  ];
  # Hermes' command provider hands over a text file and an output path. Piper
  # writes WAV, ffmpeg turns it into the Ogg/Opus Matrix voice bubbles need.
  # length-scale above 1 slows speech down (calmer); the noise values give the
  # prosody some movement instead of a flat read-out.
  speak = pkgs.writeShellApplication {
    name = "ciel-speak";
    runtimeInputs = [pkgs.piper-tts pkgs.ffmpeg-headless pkgs.coreutils];
    text = ''
      in=$1
      out=$2
      tmp=$(mktemp --suffix=.wav)
      trap 'rm -f "$tmp"' EXIT
      piper -m ${voice}/de_DE-kerstin-low.onnx -i "$in" -f "$tmp" \
        --length-scale 1.08 --noise-scale 0.75 --noise-w-scale 0.9 --sentence-silence 0.25
      ffmpeg -v error -y -i "$tmp" -c:a libopus -ac 1 -b:a 48k -application voip -f ogg "$out"
    '';
  };
in {
  inherit voice speak;
  settings = {
    provider = "ciel-piper";
    providers.ciel-piper = {
      type = "command";
      command = "${speak}/bin/ciel-speak {input_path} {output_path}";
      output_format = "ogg";
      # Without this opt-in Hermes treats the file as a plain audio attachment.
      voice_compatible = true;
      timeout = 90;
      # Voice is for short conversational replies; ciel_voice.py enforces the
      # same ceiling before it ever asks for speech.
      max_text_length = 900;
    };
  };
}
