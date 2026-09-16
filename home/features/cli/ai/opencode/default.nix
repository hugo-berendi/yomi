{
  pkgs,
  config,
  lib,
  inputs,
  osConfig ? null,
  ...
}: let
  cfg = config.yomi.ai.mcp;
  cfgRemote = config.yomi.ai.mcpRemote;
  opencodePort =
    if osConfig != null && osConfig ? yomi && osConfig.yomi ? ports && osConfig.yomi.ports ? opencode
    then osConfig.yomi.ports.opencode
    else 8487;
  opencodeAttachUrl = "http://127.0.0.1:${toString opencodePort}";
  opencodeRuntimePath = lib.makeBinPath (with pkgs; [
    bash
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    which
    git
    just
    nix
    openssh
    util-linux
    procps
    ripgrep
    fzf
    systemd
  ]);
  stylixScheme = config.lib.stylix.colors.scheme;

  opencodeTheme =
    if lib.hasPrefix "catppuccin" stylixScheme
    then "catppuccin"
    else if lib.hasPrefix "gruvbox" stylixScheme
    then "gruvbox"
    else if lib.hasPrefix "nord" stylixScheme
    then "nord"
    else "system";

  toOpencodeMcp = name: value: {
    ${name} = {
      type = "local";
      enabled = true;
      command = [value.command] ++ value.args;
    };
  };

  toOpencodeRemoteMcp = name: value: {
    ${name} = {
      type = "remote";
      enabled = true;
      inherit (value) url;
    };
  };

  mcpServers =
    lib.foldl' (acc: name: acc // toOpencodeMcp name cfg.${name}) {} (builtins.attrNames cfg)
    // lib.foldl' (acc: name: acc // toOpencodeRemoteMcp name cfgRemote.${name}) {} (builtins.attrNames cfgRemote);

  # {{{ Formatter Packages
  formatterPackages = with pkgs; [
    alejandra
    stylua
    prettierd
    biome
    ruff
    rustfmt
    gofumpt
    yamlfmt
    taplo
    shfmt
  ];
  # }}}
in {
  imports = [
    ./permissions.nix
    ./compaction.nix
    ./formatters.nix
    ./commands.nix
    ./agents.nix
    ./watcher.nix
  ];

  home.packages = formatterPackages;
  programs.opencode = {
    enable = true;
    package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

    settings = {
      model = "openai/gpt-5.3-codex";

      # {{{ MCP Servers
      mcp = mcpServers;
      # }}}
    };

    tui.theme = opencodeTheme;
  };

  yomi.persistence.at.state.apps.opencode.directories = [
    "${config.home.homeDirectory}/.local/share/opencode"
    "${config.xdg.configHome}/opencode"
  ];

  systemd.user.services.opencode-web = {
    Unit = {
      Description = "OpenCode Web Server";
      After = ["network.target"];
    };
    Service = {
      Environment = [
        "PATH=${opencodeRuntimePath}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
      ExecStart = "${lib.getExe inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode} web --hostname 127.0.0.1 --port ${toString opencodePort}";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = ["default.target"];
  };

  programs.bash.initExtra = ''
    opencode() {
      if [ "$#" -eq 0 ]; then
        command opencode attach ${opencodeAttachUrl}
      else
        command opencode "$@"
      fi
    }
  '';

  programs.fish.interactiveShellInit = ''
    function opencode
      if test (count $argv) -eq 0
        command opencode attach ${opencodeAttachUrl}
      else
        command opencode $argv
      end
    end
  '';
}
