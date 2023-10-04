#!/usr/bin/env zsh

## setup ##

[[ -o interactive ]] || return #interactive only!
[[ $TERM -eq "xterm-kitty" ]] || return # kitty only
zmodload zsh/datetime || { print "can't load zsh/datetime"; return } # faster than date()
autoload -Uz add-zsh-hook || { print "can't add zsh hook!"; return }

(( ${+kittynotify_threshold} )) || kittynotify_threshold=10 #default 10 seconds


## definitions ##

if ! (type kittynotify_formatted | grep -q 'function'); then ## allow custom function override
  function kittynotify_formatted { ## args: (exit_status, command, elapsed_seconds)
    elapsed="$(( $3 % 60 ))s"
    (( $3 >= 60 )) && elapsed="$((( $3 % 3600) / 60 ))m $elapsed"
    (( $3 >= 3600 )) && elapsed="$(( $3 / 3600 ))h $elapsed"
    [ $1 -eq 0 ] && kittynotify "#win (took $elapsed)" "$2" || kittynotify "#fail (took $elapsed)" "$2"
  }
fi

kittynotify_python="import json,sys
obj=json.load(sys.stdin)
if len(obj) and obj[0]['is_active'] and not obj[0]['is_focused']:
  print(-1)
else:
  print(obj[0]['tabs'][0]['windows'][0]['id'])"

currentWindowId () {
  echo "$(kitty @ ls --match state:focused | python -c $kittynotify_python )"
}

kittynotify () { ## args: (title, subtitle)
  printf "\x1b]99;i=1:d=0;$1\x1b\\"
  printf "\x1b]99;i=1:d=1:p=body;$2\x1b\\"
}


## Zsh hooks ##

kittynotify_begin() {
  kittynotify_timestamp=$EPOCHSECONDS
  kittynotify_lastcmd="$1"
  kittynotify_windowid=$KITTY_WINDOW_ID
}

kittynotify_end() {
  didexit=$?
  elapsed=$(( EPOCHSECONDS - kittynotify_timestamp ))
  past_threshold=$(( elapsed >= kittynotify_threshold ))
  if (( kittynotify_timestamp > 0 )) && (( past_threshold )); then
    if [ $(currentWindowId) != "$kittynotify_windowid" ]; then
      if [ "$kittynotify_play_sound" = true ]; then
        print -n "\a"
      fi
      kittynotify_formatted "$didexit" "$kittynotify_lastcmd" "$elapsed"
    fi
  fi
  kittynotify_timestamp=0 #reset it to 0!
}

## only enable if a local (non-ssh) connection
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ]; then
  add-zsh-hook preexec kittynotify_begin
  add-zsh-hook precmd kittynotify_end
fi
