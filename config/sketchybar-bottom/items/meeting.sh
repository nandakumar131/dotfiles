#!/bin/bash

sketchybar-bottom   --add item meeting right \
             --set meeting  \
                   update_freq=60 \
                   icon=$CALENDAR \
                   click_script="open '/System/Volumes/Data/Users/nvadivelu/Applications/Chrome Apps.localized/Google Calendar.app'" \
                   script="$PLUGIN_DIR/meeting.sh"
