#!/usr/bin/env sh

COUNT=0
COUNT=$(curl -s --max-time 20 https://github.com/users/nandakumar131/contributions | grep $(date '+%Y-%m-%d') | sed -nr 's/.*data-level=\"([^"]+).*/\1/p')
PREV_COUNT=$(sketchybar-top --query github.commits | jq -r .text.label)

if [ $COUNT -gt 0 ] 2>/dev/null; then
  sketchybar-top --set $NAME icon.highlight=on label="$COUNT"
else
  if [ "$COUNT" = "" ]; then
    sketchybar-top --set $NAME icon.highlight=off label="!"
  else 
    sketchybar-top --set $NAME icon.highlight=off label="$COUNT" 
  fi
fi

if [ "$COUNT" != "$PREV_COUNT" ]; then
  sketchybar-top --animate tanh 15 --set $NAME label.y_offset=5 label.y_offset=0
fi
