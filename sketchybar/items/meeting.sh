#!/bin/bash

sketchybar   --add item meeting right \
             --set meeting  \
                   update_freq=60 \
                   icon=$CALENDAR \
                   click_script="open /System/Applications/Calendar.app" \
                   script="$PLUGIN_DIR/meeting.sh"
