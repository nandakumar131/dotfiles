#!/bin/bash

sketchybar-bottom --add item cpu right                                                  \
           --set cpu                                                             \
       	         update_freq=5                                                   \
                 icon=$CPU                                                       \
                 click_script="/Applications/NeoHtop.app/Contents/MacOS/NeoHtop" \
                 script="$PLUGIN_DIR/cpu.sh"
