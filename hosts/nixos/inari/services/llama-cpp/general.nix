{
  config,
  lib,
  pkgs,
  ...
}: let
  mkLlamaServer = import ./lib.nix {inherit lib pkgs;};
  modelFile = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
  modelAlias = "qwen3.6-35b-a3b";
  contextSize = 65536;
  port = config.yomi.ports.llama-cpp;
  pilot = config.yomi.pilot.name;
in {
  # {{{ Service
  # General-purpose local model, mainly the backend of the `local-task`
  # OpenCode agent that Claude Code and Codex hand simple work to.
  #
  # Qwen3.6-35B-A3B is a mixture of experts with 3B parameters active per
  # token, so it decodes about as fast as a 3B dense model while scoring 73.4
  # on SWE-bench Verified. In October 2026 the newer Qwen3.8-Flash-Next and
  # GLM-5.3-Flash need more than 90 GB even at 3-bit quantization, and
  # Qwen3.8-27B is dense, so it would decode about nine times slower.
  #
  # It replaced a Qwen2.5-14B that nothing called: its journal had no request
  # in the seven days before the switch.
  #
  # The weights live entirely on the Radeon 680M iGPU through Vulkan. Measured
  # with llama-bench b9190 on this box (tokens per second):
  #
  #   CPU only, 8 threads             prompt  18   decode  8.4
  #   Vulkan, experts left on the CPU prompt  53   decode  6.0
  #   Vulkan, fully offloaded         prompt 172   decode 14.9
  #
  # An OpenCode request carries about 12k tokens of system prompt and tools,
  # so on the CPU alone every call would spend eleven minutes before writing a
  # word. Full offload also leaves the CPU cores to the other services. The
  # cost is 22 GB of GTT, system RAM that the GPU driver holds and the kernel
  # cannot reclaim while the service runs.
  #
  # Only 10 of the 40 layers use full attention, so a 64k context costs about
  # 1.3 GB of KV cache on top of the weights.
  imports = [
    (mkLlamaServer {
      name = "llama-cpp";
      description = "llama.cpp inference server";
      model = {
        repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
        revision = "a483e9e6cbd595906af30beda3187c2663a1118c";
        file = modelFile;
        sha256 = "707a55a8a4397ecde44de0c499d3e68c1ad1d240d1da65826b4949d1043f4450";
      };
      package = pkgs.llama-cpp-vulkan;
      args = [
        "--alias"
        modelAlias
        "--host"
        "127.0.0.1"
        "--port"
        (toString port)
        # Tool calls need the model's own chat template.
        "--jinja"
        "--ctx-size"
        (toString contextSize)
        # One agent at a time. Every extra slot splits the context and the
        # GPU between concurrent requests.
        "--parallel"
        "1"
        "--flash-attn"
        "on"
        "--n-gpu-layers"
        "99"
        # Read the weights straight into GPU memory. An mmap would also leave
        # a second 22 GB copy in this unit's page cache.
        "--no-mmap"
        # The OOM dump held 19 GiB in TTM buffers outside MemoryMax while
        # zram was full. Release the idle model; requests reload it on demand.
        "--sleep-idle-seconds"
        "60"
        # The GPU does the math. The CPU only samples and schedules.
        "--threads"
        "4"
        # Qwen's recommended thinking-mode settings for precise coding.
        "--temp"
        "0.6"
        "--top-p"
        "0.95"
        "--top-k"
        "20"
        "--min-p"
        "0"
      ];
      limits = {
        # The GTT buffers holding the weights are not charged to this cgroup, so
        # the limit only covers the process heap and the load buffers.
        MemoryMax = "4G";
        CPUQuota = "400%";
        # When the box is busy, every other service wins the CPU and the disk.
        # An agent waiting a few seconds longer matters less.
        CPUWeight = 20;
        IOWeight = 20;
        Nice = 10;
      };
      # PrivateDevices would hide the render node, so the allow-list names the
      # one device Vulkan needs.
      sandbox = {
        PrivateDevices = false;
        DevicePolicy = "closed";
        DeviceAllow = ["/dev/dri/renderD128 rw"];
        SupplementaryGroups = ["render"];
      };
    })
  ];
  # }}}
  # {{{ OpenCode provider
  home-manager.users.${pilot}.programs.opencode.settings.provider.llama-cpp = {
    npm = "@ai-sdk/openai-compatible";
    name = "llama.cpp (local)";
    options.baseURL = "http://127.0.0.1:${toString port}/v1";
    models.${modelAlias} = {
      name = "Qwen3.6 35B-A3B (local)";
      tool_call = true;
      reasoning = true;
      limit = {
        context = contextSize;
        output = 16384;
      };
    };
  };
  # }}}
}
