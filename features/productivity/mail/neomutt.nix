{config, ...}: {
  # {{{ hugob
  accounts.email.accounts.hugob.neomutt = {
    enable = true;
    sendMailCommand = "msmtpq --read-envelope-from --read-recipients";
    extraMailboxes = [
      "Archive"
      "Drafts"
      "Junk"
      "Sent"
      "Trash"
    ];
    # The account's gpg block makes neomutt sign but does not name a key, so
    # gpgme would choose by From address. The revoked 2024 key has the same
    # address and is still in the keyring on amaterasu; name the key.
    extraConfig = ''
      set pgp_default_key = "${config.yomi.pilot.gpgKey}"
    '';
  };
  # }}}

  # {{{ Neomutt
  programs.neomutt = {
    # {{{ Primary config
    enable = true;
    vimKeys = true;
    checkStatsInterval = 60; # How often to check for new mail
    sidebar = {
      enable = true;
      width = 30;
    };
    # }}}

    binds = [
      # {{{ Toggle sidebar
      {
        map = [
          "index"
          "pager"
        ];
        key = "B";
        action = "sidebar-toggle-visible";
      }
      # }}}
      # {{{ Highlight previous sidebar item
      {
        map = [
          "index"
          "pager"
        ];
        key = "\\CK";
        action = "sidebar-prev";
      }
      # }}}
      # {{{ Highlight next sidebar item
      {
        map = [
          "index"
          "pager"
        ];
        key = "\\CJ";
        action = "sidebar-next";
      }
      # }}}
      # {{{ Open highlighted sidebar item
      {
        map = [
          "index"
          "pager"
        ];
        key = "\\CO";
        action = "sidebar-open";
      }
      # }}}
    ];

    macros = [
      # {{{ Sync emails
      {
        map = ["index"];
        key = "S";
        action = "<shell-escape>mbsync -a<enter><shell-escape>notmuch new<enter>";
      }
      # }}}
      # # {{{ show only messages matching a notmuch pattern
      # {
      #   map = [ "index" ];
      #   key = "\\Cf";
      #   action = ''"<enter-command>unset wait_key<enter><shell-escape>read -p 'Enter a search term to find with notmuch: ' x;''
      #     + ''echo \\$x >~/.cache/mutt_terms<enter><limit>~i \\"\\`notmuch search - -output=messages \\$(cat ~/.cache/mutt_terms) ''
      #     + ''| head -n 600 | perl -le '@a=<>;s/\^ id:// for@a;$, = \\"|\\";print@a' | perl -le '@a=<>; chomp@a; s/\\\\+/\\\\\\\\+/ for@a;print@a' \`\\"<enter>"'';
      # }
      # # }}}
    ];

    extraConfig = ''
      # Starting point: https://seniormars.com/posts/neomutt/#introduction-and-why
      # {{{ Settings
      set pager_index_lines = 10
      set pager_context = 3                # show 3 lines of context
      set pager_stop                       # stop at end of message
      set menu_scroll                      # scroll menu
      set tilde                            # use ~ to pad mutt
      set move=no                          # don't move messages when marking as read
      set sleep_time = 0                   # don't sleep when idle
      set wait_key = no		     # mutt won't ask "press key to continue"
      set envelope_from                    # which from?
      # set edit_headers                     # show headers when composing
      set fast_reply                       # skip to compose when replying
      set askcc                            # ask for CC:
      set fcc_attach                       # save attachments with the body
      set forward_format = "Fwd: %s"       # format of subject when forwarding
      set forward_decode                   # decode when forwarding
      set forward_quote                    # include message in forwards
      set mime_forward                     # forward attachments as part of body
      set attribution = "On %d, %n wrote:" # format of quoting header
      set reply_to                         # reply to Reply to: field
      set reverse_name                     # reply as whomever it was to
      set include                          # include message in replies
      set text_flowed=yes                  # correct indentation for plain text
      unset sig_dashes                     # no dashes before sig
      unset markers
      # }}}
      # {{{ Sort by newest conversation first.
      set charset = "utf-8"
      set uncollapse_jump
      set sort_re
      set sort = reverse-threads
      set sort_aux = last-date-received
      # }}}
      # {{{ How we reply and quote emails.
      set reply_regexp = "^(([Rr][Ee]?(\[[0-9]+\])?: *)?(\[[^]]+\] *)?)*"
      set quote_regexp = "^( {0,4}[>|:#%]| {0,4}[a-z0-9]+[>|]+)+"
      set send_charset = "utf-8:iso-8859-1:us-ascii" # send in utf-8
      # }}}
      # {{{ Sidebar
      set sidebar_visible # comment to disable sidebar by default
      set sidebar_short_path
      set sidebar_folder_indent
      set sidebar_format = "%B %* [%?N?%N / ?%S]"
      set mail_check_stats
      # }}}
    '';
  };

  # {{{ Neomutt desktop entry
  # Taken from here: https://github.com/Misterio77/yomi/blob/main/home/misterio/features/productivity/neomutt.nix
  xdg = {
    desktopEntries = {
      neomutt = {
        name = "Neomutt";
        genericName = "Email Client";
        comment = "Read and send emails";
        exec = "neomutt %U";
        icon = "mutt";
        terminal = true;
        categories = [
          "Network"
          "Email"
          "ConsoleOnly"
        ];
        type = "Application";
        mimeType = ["x-scheme-handler/mailto"];
      };
    };
    mimeApps.defaultApplications = {
      "x-scheme-handler/mailto" = "neomutt.desktop";
    };
  };
  # }}}
  # }}}
}
