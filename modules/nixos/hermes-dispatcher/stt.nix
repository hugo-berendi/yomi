# Local speech-to-text for voice messages, run by Hermes' bundled faster-whisper.
{pkgs}: let
  revision = "536b0662742c02347bc0e980a01041f333bce120";
  file = name: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/Systran/faster-whisper-small/resolve/${revision}/${name}";
      inherit hash;
    };
  # faster-whisper loads a directory path directly. Hermes' default would
  # download the model from Hugging Face during the first voice message, which
  # took about 30 s on inari and needs network access in the gateway sandbox.
  model = pkgs.linkFarm "faster-whisper-small-${builtins.substring 0 7 revision}" [
    {
      name = "config.json";
      path = file "config.json" "sha256-tVSWrHlAp65H0sAeq0Dt/YcB/uwSKdnM47QAFDg/uCg=";
    }
    {
      name = "model.bin";
      path = file "model.bin" "sha256-PjBZIVBtiHKBYCPkwnPnXSQZ+4myTal7T+e84UFw1nE=";
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
    # Hermes ships stt.language = "en" because auto-detection misreads short
    # English clips. That forces English decoding, so German speech came back as
    # an English paraphrase. An empty value restores Whisper's own detection,
    # which also keeps English voice notes working: forcing "de" instead
    # produced a word error rate of 0.95 on an English test clip.
    language = "";
    local = {
      model = toString model;
      language = "";
      # Hermes would otherwise probe for CUDA first. CTranslate2 resolves "auto"
      # to int8 on this CPU anyway (same latency measured), so pin it.
      device = "cpu";
      compute_type = "int8";
      # Keep the loaded model resident; reloading costs about 2.5 s per cold start.
      unload_after_idle_seconds = 0;
    };
  };
}
