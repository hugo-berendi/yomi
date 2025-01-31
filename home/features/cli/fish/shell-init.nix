{pkgs, ...}: {
  programs.fish.shellInit =
    /*
    fish
    */
    ''
      # {{{ Sets cursor based on vim mode
      set fish_cursor_default block # Set the normal and visual mode cursors to a block
      set fish_cursor_insert line # Set the insert mode cursor to a line
      set fish_cursor_replace_one underscore # Set the replace mode cursor to an underscore

      # Force fish to skip some checks (I think?)
      set fish_vi_force_cursor
      # }}}
      # {{{ Disable greeting
      set fish_greeting
      # }}}

      set VIRTUAL_ENV_DISABLE_PROMPT 1
      set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
      set -x SHELL ${pkgs.fish}/bin/fish

      ## Export variable needed for qt-theme
      if type qtile >>/dev/null 2>&1
          set -x QT_QPA_PLATFORMTHEME qt5ct
      end

      # Set settings for https://github.com/franciscolourenco/done
      set -U __done_min_cmd_duration 10000
      set -U __done_notification_urgency_level low

      # Apply .profile: use this to put fish compatible .profile stuff in
      if test -f ~/.fish_profile
          source ~/.fish_profile
      end

      set -p PATH /home/hugob/.local/bin
      set -p PATH /home/hugob/.cargo/bin
      set -p PATH /home/hugob/.local/share/gem/ruby/3.0.0/bin

      # Add ~/.local/bin to PATH
      if test -d ~/.local/bin
          if not contains -- ~/.local/bin $PATH
              set -p PATH ~/.local/bin
          end
      end

      # Add depot_tools to PATH
      if test -d ~/Applications/depot_tools
          if not contains -- ~/Applications/depot_tools $PATH
              set -p PATH ~/Applications/depot_tools
          end
      end

      if [ "$fish_key_bindings" = fish_vi_key_bindings ]
          bind -Minsert ! __history_previous_command
          bind -Minsert '$' __history_previous_command_arguments
      else
          bind ! __history_previous_command
          bind '$' __history_previous_command_arguments
      end


      # Add scripts to PATH

      set -p PATH ~/.config/scripts

      # Set screenshot and image folders
      set HYPRSHOT /home/hugob/Pictures
      set XDG_PICTURES_DIR /home/hugob/Pictures

      # Android SDK
      set ANDROID_HOME /home/hugob/Android/Sdk
      set -p PATH $ANDROID_HOME/build_tools
      set -p PATH $ANDROID_HOME/platform-tools
      set -p PATH $ANDROID_HOME/cmdline-tools

      # Add bun to PATH
      set --export BUN_INSTALL "$HOME/.bun"
      set --export PATH $BUN_INSTALL/bin $PATH
      fish_add_path /home/hugob/.spicetify

      # Direnv hook
      direnv hook fish | source

      # setup thefuck
      thefuck --alias | source
    '';
}
