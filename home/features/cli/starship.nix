{lib, ...}: {
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableTransience = true;
    settings = {
      # Inserts a blank line between shell prompts
      add_newline = true;

      # Custom format for the prompt
      format = lib.concatStrings [
        "[](mantle)$os"
        "[](fg:mantle bg:crust)$directory"
        "[](fg:crust bg:surface0)$git_branch$git_status"
        "[](fg:surface0 bg:surface1)$nodejs$rust$golang$php"
        "[](fg:surface1 bg:surface2)$time"
        "[](fg:surface2)\n$character"
      ];

      # OS segment configuration
      os = {
        format = "[$symbol]($style)";
        style = "bg:mantle fg:mauve";
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
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
      };

      # Directory segment configuration
      directory = {
        style = "fg:mauve bg:crust";
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
        style = "bg:base";
        format = "[[ $symbol $branch ](fg:mauve bg:surface0)]($style)";
      };

      # Git status segment configuration
      git_status = {
        style = "bg:base";
        format = "[[($all_status$ahead_behind )](fg:mauve bg:surface0)]($style)";
      };

      # NodeJS segment configuration
      nodejs = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:mauve bg:surface1)]($style)";
      };

      # Rust segment configuration
      rust = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:mauve bg:surface1)]($style)";
      };

      # GoLang segment configuration
      golang = {
        symbol = "ﳑ";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:mauve bg:surface1)]($style)";
      };

      # PHP segment configuration
      php = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:mauve bg:surface1)]($style)";
      };

      # Time segment configuration
      time = {
        disabled = false;
        time_format = "%R"; # Hour:Minute:Second Format
        style = "bg:surface2 fg:mauve";
        format = "[ 󱑍 $time ]($style)";
      };

      # Custom palettes definition
      palettes = {
        catppuccin_mocha = {
          rosewater = "#f5e0dc";
          flamingo = "#f2cdcd";
          pink = "#f5c2e7";
          mauve = "#eb6f92";
          red = "#ea9a97";
          maroon = "#eba0ac";
          peach = "#fab387";
          yellow = "#f9e2af";
          green = "#3e8fb0";
          teal = "#94e2d5";
          sky = "#89dceb";
          sapphire = "#74c7ec";
          blue = "#89b4fa";
          lavender = "#b4befe";
          text = "#cdd6f4";
          subtext1 = "#bac2de";
          subtext0 = "#a6adc8";
          overlay2 = "#625e5a";
          overlay1 = "#393836";
          overlay0 = "#282727";
          surface2 = "#393552";
          surface1 = "#2a273f";
          surface0 = "#26233a";
          base = "#191724";
          mantle = "#191724";
          crust = "#1f1d2e";
        };
      };
    };
  };
}
