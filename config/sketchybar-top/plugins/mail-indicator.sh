#!/usr/bin/env sh
source "$CONFIG_DIR/icons.sh"

RUNNING=$(osascript -e 'if application "Mail" is running then return 0')
COUNT=0

if [ "$RUNNING" = "0" ]; then
  COUNT=$(osascript -e 'tell application "Mail" to return the unread count of inbox')
  if [ "$COUNT" -gt "0" ]; then
    sketchybar-top --set $NAME label="$COUNT" icon=$MAIL
  else
    sketchybar-top --set $NAME label="$COUNT" icon=$MAIL_OPEN
  fi
else
  sketchybar-top --set $NAME label="!" icon=$MAIL
fi
