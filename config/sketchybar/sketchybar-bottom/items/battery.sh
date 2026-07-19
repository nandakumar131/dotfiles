#!/bin/bash

sketchybar-bottom --add item battery right \
  --set battery update_freq=60 \
  script="$PLUGIN_DIR/battery.sh" \
  --subscribe battery system_woke power_source_change
