#!/usr/bin/env sh

COUNT=0
COUNT=$(/Applications/gh/bin/gh api notifications | jq '.[].subject.title' | wc -l | xargs)
PREV_COUNT=$(sketchybar-bottom --query github.notification | jq -r .text.label)

if [ $COUNT -gt 0 ] 2>/dev/null; then
  sketchybar-bottom --set $NAME icon.highlight=on label="$COUNT"
else
  if [ "$COUNT" = "" ]; then
    sketchybar-bottom --set $NAME icon.highlight=off label="!"
  else 
    sketchybar-bottom --set $NAME icon.highlight=off label="$COUNT" 
  fi
fi

if [ "$COUNT" != "$PREV_COUNT" ]; then
  sketchybar-bottom --animate tanh 15 --set $NAME label.y_offset=5 label.y_offset=0
fi
