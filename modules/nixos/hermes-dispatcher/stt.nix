# Local speech-to-text for voice messages, run by Hermes' bundled faster-whisper.
{pkgs}: let
  revision = "ebe41f70d5b6dfa9166e2c581c45c9c0cfc57b66";
  file = name: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/Systran/faster-whisper-base/resolve/${revision}/${name}";
      inherit hash;
    };
  # faster-whisper loads a directory path directly. Hermes' default would
  # download the model from Hugging Face during the first voice message, which
  # took about 30 s on inari and needs network access in the gateway sandbox.
  model = pkgs.linkFarm "faster-whisper-base-${builtins.substring 0 7 revision}" [
    {
      name = "config.json";
      path = file "config.json" "sha256-VqbYEQ0xHxnI8EceVigyx1J/FGtWcnW/yln898GE2po=";
    }
    {
      name = "model.bin";
      path = file "model.bin" "sha256-0BwwFIgcnG8xM8GC89KIfrbKHHiadTjFwAcZaFegpqk=";
    }
    {
      name = "tokenizer.json";
      path = file "tokenizer.json" "sha256-+3tjGR6bsEUILHn9dCoxBqEsmVE6sw30oNR/pstv0Ks=";
    }
    {
      name = "vocabulary.txt";
      path = file "vocabulary.txt" "sha256-NM4/4cUEECez+NQpEicJk/mG28S7NM8n+VHjSh5FORM=";
    }
  ];
in {
  inherit model;
  settings = {
    enabled = true;
    provider = "local";
    # Hermes echoes every transcript back as a separate chat message by
    # default. The transcript still becomes the user turn Ciel answers; only
    # the echo goes. It runs after transcription, so decryption and decoding
    # of encrypted voice messages are untouched.
    echo_transcripts = false;
    # Hermes ships stt.language = "en", which forces English decoding, so German
    # speech came back as an English paraphrase. Pin German instead of using
    # auto-detection: detection costs about 58% more CPU per clip on the base
    # model (22.4 s -> 35.5 s per 10 clips, single thread, quiet host). Base
    # with "de" still passes English speech through mostly intact (4 of 5 test
    # clips exact; one noisy clip was garbled).
    language = "de";
    local = {
      model = toString model;
      language = "de";
      # Pinned to skip Hermes' CUDA probe. "auto" resolves to int8 on this CPU
      # and timed the same as int8 and float32.
      device = "cpu";
      compute_type = "int8";
      # Keep the loaded model resident; reloading costs about 2.5 s per cold start.
      unload_after_idle_seconds = 0;
    };
  };
}
