_: {
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableTransience = true;
    settings = {
      format = ''
        $username$directory$git_branch$git_status$nix_shell$fill$c$elixir$elm$golang$haskell$java$julia$nodejs$nim$rust$scala$conda$python$time
        $character'';
      palette = "rose-pine-moon";

      palettes = {
        rose-pine-moon = {
          overlay = "#393552";
          love = "#eb6f92";
          gold = "#f6c177";
          rose = "#ea9a97";
          pine = "#3e8fb0";
          foam = "#9ccfd8";
          iris = "#c4a7e7";
        };
      };

      character = {
        format = "[󱞪](fg:iris) ";
      };

      directory = {
        format = "[](fg:overlay)[ $path ]($style)[](fg:overlay) ";
        style = "bg:overlay fg:pine";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          Documents = "󰈙";
          Downloads = " ";
          Music = " ";
          Pictures = " ";
        };
      };

      fill = {
        style = "fg:overlay";
        symbol = " ";
      };

      git_branch = {
        format = "[](fg:overlay)[ $symbol $branch ]($style)[](fg:overlay) ";
        style = "bg:overlay fg:foam";
        symbol = "";
      };

      git_status = {
        disabled = false;
        style = "bg:overlay fg:love";
        format = "[](fg:overlay)([$all_status$ahead_behind]($style))[](fg:overlay) ";
        up_to_date = "[ ✓ ](bg:overlay fg:iris)";
        untracked = "[?\($count\)](bg:overlay fg:gold)";
        # The dollar has to reach starship escaped. It is the sigil for a
        # variable, so a bare one followed by `(` makes the whole format string
        # fail to parse. Every neighbour here starts with an ordinary character
        # and so needs no escape.
        stashed = "[\\$\($count\)](bg:overlay fg:iris)";
        modified = "[!\($count\)](bg:overlay fg:gold)";
        renamed = "[»\($count\)](bg:overlay fg:iris)";
        deleted = "[✘\($count\)](style)";
        staged = "[++\($count\)](bg:overlay fg:gold)";
        ahead = "[⇡\($count\)](bg:overlay fg:foam)";
        diverged = "⇕[\[](bg:overlay fg:iris)[⇡\($ahead_count\)](bg:overlay fg:foam)[⇣\($behind_count\)](bg:overlay fg:rose)[\]](bg:overlay fg:iris)";
        behind = "[⇣\($count\)](bg:overlay fg:rose)";
      };

      time = {
        disabled = false;
        format = "[](fg:overlay)[ $time  ]($style)[](fg:overlay)";
        style = "bg:overlay fg:rose";
        time_format = "%I:%M%P";
        use_12hr = true;
      };

      username = {
        disabled = false;
        format = "[](fg:overlay)[ 󰧱 $user ]($style)[](fg:overlay) ";
        show_always = true;
        style_root = "bg:overlay fg:iris";
        style_user = "bg:overlay fg:iris";
      };

      hostname = {
        disabled = false;
        ssh_only = true;
        ssh_symbol = "󰢹 ";
        format = "[](fg:overlay)[ $hostname ]($style)[](fg:overlay) ";
        style = "bg:overlay fg:iris";
      };

      nix_shell = {
        disabled = false;
        format = "[](fg:overlay)[ ❄ $state ]($style)[](fg:overlay) ";
        style = "bg:overlay fg:foam";
        impure_msg = "✗";
        pure_msg = "✓";
        unknown_msg = "?";
      };

      # Language-specific configurations
      c = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = " ";
      };

      elixir = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = " ";
      };

      elm = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = " ";
      };

      golang = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = " ";
      };

      haskell = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = " ";
      };

      java = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = " ";
      };

      julia = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = " ";
      };

      nodejs = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = "󰎙 ";
      };

      nim = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = "󰆥 ";
      };

      rust = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = "";
      };

      scala = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = " ";
      };

      python = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$version]($style)[](fg:overlay) ";
        disabled = false;
        symbol = " ";
      };

      conda = {
        style = "bg:overlay fg:pine";
        format = "[](fg:overlay)[$symbol$environment]($style)[](fg:overlay) ";
        disabled = false;
        symbol = "🅒 ";
      };
    };
  };
}
