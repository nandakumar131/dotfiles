#!/bin/bash

sketchybar-top --add item ram right                                                  \
           --set ram                                                             \
                 update_freq=60                                                  \
                 icon=$MEMORY                                                    \
                 click_script="/Applications/NeoHtop.app/Contents/MacOS/NeoHtop" \
                 script="$PLUGIN_DIR/ram.sh"
