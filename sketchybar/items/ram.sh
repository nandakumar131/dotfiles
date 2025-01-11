#!/bin/bash

sketchybar --add item ram right \
  --set ram update_freq=60 \
  icon= script="$PLUGIN_DIR/ram.sh"
