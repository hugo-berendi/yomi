{
  config,
  lib,
  pkgs,
  ...
}: let
  mkLlamaServer = import ./lib.nix {inherit lib pkgs;};
  port = config.yomi.ports.llama-cpp-classifier;
  # nixpkgs builds llama.cpp for the x86-64 baseline (GGML_NATIVE off, as
  # -march=native would make the build depend on the builder). That leaves
  # out every vector instruction: Qwen3.5-9B processed prompts at 9 tokens/s
  # and took ~56 s a mail, where Ollama, which ships CPU variants, took ~31 s.
  # The features are named instead of detected, for inari's Ryzen 7 7735HS
  # (Zen 3+): AVX2, FMA, F16C, BMI2, no AVX-512.
  llamaCpp = pkgs.llama-cpp.overrideAttrs (old: {
    cmakeFlags =
      old.cmakeFlags
      ++ map (feature: lib.cmakeBool "GGML_${feature}" true) ["AVX" "AVX2" "FMA" "F16C" "BMI2"];
  });
in {
  # {{{ Service
  # A second llama.cpp beside the general model next door, for classification
  # work: the Proton mail sorter and the diabetes app's weekly review.
  #
  # Qwen3.5-9B replaced Qwen2.5-3B in October 2026, when the Proton sorter
  # arrived with a prompt and thirteen categories tuned to it. Against twenty
  # labelled synthetic mails it filed 19 correctly at ~31 s each on this CPU
  # (the miss, an expired 2019 deadline filed as Wichtig, is now caught in the
  # sorter's code). It briefly ran under Ollama; one runtime is enough, and
  # Ollama is llama.cpp underneath anyway.
  #
  # The 3B it replaced had been chosen by measurement for the old Migadu
  # organizer: 92% on twelve mails at 11 s, against 67% for Qwen3-1.7B, which
  # filed a doctor's appointment as unsolicited bulk. That trade no longer
  # holds once the work runs in the background with minutes to spare.
  #
  # The model is six gigabytes fetched over the network: worth keeping across
  # reboots, and it is regenerable, so its state directory belongs beside the
  # other caches rather than in a backup set.
  imports = [
    (mkLlamaServer {
      name = "llama-cpp-classifier";
      description = "llama.cpp inference server for mail classification";
      model = {
        repo = "unsloth/Qwen3.5-9B-GGUF";
        revision = "3885219b6810b007914f3a7950a8d1b469d598a5";
        file = "Qwen3.5-9B-Q4_K_M.gguf";
        sha256 = "03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8";
      };
      package = llamaCpp;
      args = [
        "--alias"
        "qwen3.5-9b"
        "--host"
        "127.0.0.1"
        "--port"
        (toString port)
        # The sorter's system prompt is about 3k tokens and a mail excerpt up
        # to 2k more. One slot keeps the whole context for one request and
        # lets the prompt cache reuse the system prompt between mails.
        "--ctx-size"
        "8192"
        "--parallel"
        "1"
        # Qwen3.5 thinks by default. Classification wants a label, not an
        # essay, and the thinking tokens would cost minutes per mail here.
        "--jinja"
        "--reasoning"
        "off"
        "--threads"
        "8"
      ];
      # CPU only: the iGPU already holds the 35B next door. Eight threads,
      # but the lowest weight, so the services this box exists to run win
      # whenever they want the CPU. ~5.7 GB of weights plus the 8k context.
      limits = {
        MemoryMax = "10G";
        CPUQuota = "800%";
        CPUWeight = 20;
        IOWeight = 20;
        Nice = 10;
      };
    })
  ];
  # }}}
}
