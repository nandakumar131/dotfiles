#!/bin/bash

sketchybar-top --add item clock right \
  --set clock update_freq=10 \
  script="$PLUGIN_DIR/clock.sh"
