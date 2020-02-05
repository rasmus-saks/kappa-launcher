#!/bin/bash

# Checking dependencies
JQ_BIN="$(whereis -b jq | awk '{print $2}')"
ROFI_BIN="$(whereis -b rofi | awk '{print $2}')"

if [ -z "$JQ_BIN" ]; then
  echo "Kappa launcher dependency not found: jq"
  exit 1
fi
if [ -z "$ROFI_BIN" ]; then
  echo "Kappa launcher dependency not found: rofi"
  exit 1
fi

# Some functions
_config () {
  mkdir -p $MAIN_PATH
  cat << EOF >$FILE
# Either streamlink or browser, default streamlink
PLAYER=streamlink

# Either chatterino or chatty, default chatterino. Irrelevant when using browser.
CHAT=chatterino

# OAuth
OAUTH=replace_this_with_oauth_string
EOF
}

_filecheck () {
  if [ -f "$FILE" ]; then
    echo "Configuration file found, proceeding"
  else
    echo "Configuration file not found, generating it now"
    _config
    echo "Configuration file generated successfully in .config/kpl, please edit it with your OAuth key"
    exit
  fi
}

_rofi () {
  rofi -dmenu -i -no-levenshtein-sort -disable-history -scroll-method 1 -theme-str "$@"
}

_launcher () {
  if [[ "$PLAYER" = "streamlink" ]]; then
    killall -9 vlc &    # This is required because VLC is annoying. If you use a different media player, remove this line.
    streamlink twitch.tv/$MAIN best &
    echo "launching $PLAYER"
    if [[ "$CHAT" = "chatterino" ]]; then
      chatterino &
    elif [[ "$CHAT" = "chatty" ]]; then
      chatty
    else
      echo "Chat not defined in config file"
    fi
  elif [[ "$PLAYER" = "browser" ]]; then
    xdg-open https://twitch.tv/$MAIN
  else
    echo "Player not defined in config file"
  fi
  x=$(( $x + 1))
}

# Setting working directory, checking for configuration file, generating it if needed

if [ -z "$XDG_CONFIG_HOME" ]; then
  FILE=~/.config/kpl/config
  MAIN_PATH=~/.config/kpl
  _filecheck
else
  FILE=$XDG_CONFIG_HOME/kpl/config
  MAIN_PATH=$XDG_CONFIG_HOME/kpl
  _filecheck
fi

# Grab configuration file
source $MAIN_PATH/config

# Setting OAuth key, connecting to Twitch API and retrieving followed data
# This is a slightly edited version of https://github.com/begs/livestreamers/blob/master/live.py

curl -s -o $MAIN_PATH/followdata.json -H "Accept: application/vnd.twitchtv.v5+json" \
-H "Client-ID: 3lyhpjkzellmam3843w7eq3es84375" \
-H "Authorization: OAuth $OAUTH" \
-X GET "https://api.twitch.tv/kraken/streams/followed" \

# Getting names of currently live streams
x=1
while [[ $x -le 1 ]]; do
  STREAMS=$(jq -r '.streams[].channel.display_name' $MAIN_PATH/followdata.json)

  # Listing said streams with rofi
  MAIN=$(echo "$STREAMS" | _rofi 'inputbar { children: [prompt,entry];}' -p "Followed channels: ")
  if [[ "$STREAMS" != *"$MAIN"* ]]; then
    _launcher
  elif [ -z "$MAIN" ]; then
    exit
  else
    # Retrieving additional information
    CURRENT_GAME=$(jq -r ".streams[].channel | select(.display_name==\"$MAIN\") | .game"  $MAIN_PATH/followdata.json)
    STATUS=$(jq -r ".streams[].channel | select(.display_name==\"$MAIN\") | .status"  $MAIN_PATH/followdata.json)
    VIEWERS=$(jq -r ".streams[] | select(.channel.display_name==\"$MAIN\") | .viewers"  $MAIN_PATH/followdata.json)

    # Prompting with stream info and options
    CHOICE=$(echo "$STATUS

<b>Watch now</b>
Back to Followed Channels" | _rofi 'inputbar { children: [prompt];}' -selected-row 2 -no-custom -markup-rows -p "$MAIN is streaming $CURRENT_GAME to $VIEWERS viewers")

    if [[ "$CHOICE" = "<b>Watch now</b>" ]]; then
      _launcher
    elif [[ "$CHOICE" = "Back to Followed Channels" ]]; then
      return
    else [ -z "$MAIN" ];
      exit
    fi
  fi

done