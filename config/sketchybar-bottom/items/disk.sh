#!/bin/bash

sketchybar-bottom --add item disk right                                                 \
           --set disk                                                            \
	         update_freq=500                                                 \
                 icon=$DISK                                                      \
                 click_script="/Applications/NeoHtop.app/Contents/MacOS/NeoHtop" \
                 script="$PLUGIN_DIR/disk.sh"
