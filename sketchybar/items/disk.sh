#!/bin/bash

sketchybar --add item disk right \
  --set disk update_freq=500 \
  icon=󰋊 script="$PLUGIN_DIR/disk.sh"
