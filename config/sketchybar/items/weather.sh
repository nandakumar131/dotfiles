#!/bin/bash

sketchybar --add item weather right \
  --set weather update_freq=600 \
 script="$PLUGIN_DIR/weather.sh"
