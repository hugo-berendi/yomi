{
  lib,
  config,
  ...
}: {
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableTransience = true;
    settings = {
      # Inserts a blank line between shell prompts
      add_newline = true;
      palette = "base16";

      # Custom format for the prompt
      format = lib.concatStrings [
        "[](fg:color)$os"
        "[](fg:color bg:base00)$directory"
        "[](fg:base00 bg:base01)$git_branch$git_status"
        "[](fg:base01 bg:base01)$nodejs$rust$golang$php"
        "[](fg:base01 bg:base02)$time"
        "[](fg:base02)\n$character"
      ];

      # OS segment configuration
      os = {
        format = "[$symbol]($style)";
        style = "bg:color fg:base00";
        disabled = false;

        symbols = {
          Alpaquita = "🔔 ";
          Alpine = "🏔️ ";
          Amazon = "🙂 ";
          Android = "🤖 ";
          Arch = "󰣇";
          Artix = "🎗️ ";
          CentOS = "💠 ";
          Debian = "🌀 ";
          DragonFly = "🐉 ";
          Emscripten = "🔗 ";
          EndeavourOS = "🚀 ";
          Fedora = "🎩 ";
          FreeBSD = "😈 ";
          Garuda = "";
          Gentoo = "🗜️ ";
          HardenedBSD = "🛡️ ";
          Illumos = "🐦 ";
          Linux = "🐧 ";
          Mabox = "📦 ";
          Macos = "";
          Manjaro = "";
          Mariner = "🌊 ";
          MidnightBSD = "🌘 ";
          Mint = "🌿 ";
          NetBSD = "🚩 ";
          NixOS = "󱄅";
          OpenBSD = "🐡 ";
          OpenCloudOS = "☁️ ";
          openEuler = "🦉 ";
          openSUSE = "🦎 ";
          OracleLinux = "🦴 ";
          Pop = "🍭 ";
          Raspbian = "";
          Redhat = "🎩 ";
          RedHatEnterprise = "🎩 ";
          Redox = "🧪 ";
          Solus = "⛵ ";
          SUSE = "🦎 ";
          Ubuntu = "";
          Unknown = "";
          Windows = "";
        };
      };

      # Character segment configuration
      character = {
        success_symbol = "[❯](base0B)";
        error_symbol = "[❯](color)";
      };

      # Directory segment configuration
      directory = {
        style = "fg:color bg:base00";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";

        substitutions = {
          "Documents" = " ";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
        };
      };

      # Git branch segment configuration
      git_branch = {
        symbol = "";
        style = "bg:base01";
        format = "[[ $symbol $branch ](fg:color bg:base01)]($style)";
      };

      # Git status segment configuration
      git_status = {
        style = "bg:base01";
        format = "[[($all_status$ahead_behind )](fg:color bg:base01)]($style)";
      };

      # NodeJS segment configuration
      nodejs = {
        symbol = "";
        style = "bg:base02";
        format = "[[ $symbol ($version) ](fg:color bg:base02)]($style)";
      };

      # Rust segment configuration
      rust = {
        symbol = "";
        style = "bg:base02";
        format = "[[ $symbol ($version) ](fg:color bg:base02)]($style)";
      };

      # GoLang segment configuration
      golang = {
        symbol = "ﳑ";
        style = "bg:base02";
        format = "[[ $symbol ($version) ](fg:color bg:base02)]($style)";
      };

      # PHP segment configuration
      php = {
        symbol = "";
        style = "bg:base02";
        format = "[[ $symbol ($version) ](fg:color bg:base02)]($style)";
      };

      # Time segment configuration
      time = {
        disabled = false;
        time_format = "%R"; # Hour:Minute:Second Format
        style = "bg:base02 fg:color";
        format = "[ 󱑍 $time ]($style)";
      };

      # Custom palettes definition
      palettes = {
        base16 = {
          color = config.lib.stylix.scheme.withHashtag.base0D;
          base00 = config.lib.stylix.scheme.withHashtag.base00;
          base01 = config.lib.stylix.scheme.withHashtag.base01;
          base02 = config.lib.stylix.scheme.withHashtag.base02;
          base03 = config.lib.stylix.scheme.withHashtag.base03;
          base04 = config.lib.stylix.scheme.withHashtag.base04;
          base05 = config.lib.stylix.scheme.withHashtag.base05;
          base06 = config.lib.stylix.scheme.withHashtag.base06;
          base07 = config.lib.stylix.scheme.withHashtag.base07;
          base08 = config.lib.stylix.scheme.withHashtag.base08;
          base09 = config.lib.stylix.scheme.withHashtag.base09;
          base0A = config.lib.stylix.scheme.withHashtag.base0A;
          base0B = config.lib.stylix.scheme.withHashtag.base0B;
          base0C = config.lib.stylix.scheme.withHashtag.base0C;
          base0E = config.lib.stylix.scheme.withHashtag.base0E;
          base0F = config.lib.stylix.scheme.withHashtag.base0F;
        };
      };
    };
  };
}
