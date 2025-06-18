#!/bin/bash

STATE="$(echo "$INFO" | jq -r '.state')"
if [ "$STATE" = "playing" ]; then
  MEDIA="$(echo "$INFO" | jq -r '.title + " - " + .artist')"
  sketchybar-top --set $NAME label="$MEDIA" drawing=on
else
  sketchybar-top --set $NAME drawing=off
fi
