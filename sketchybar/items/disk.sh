#!/bin/bash

sketchybar --add item disk right \
  --set disk update_freq=60 \
  icon=󰋊 script="$PLUGIN_DIR/disk.sh"
