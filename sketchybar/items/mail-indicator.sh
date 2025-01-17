#!/bin/bash

sketchybar --add       item           mail.count right                         \
           --set       mail.count     update_freq=60                           \
                                      icon.highlight_color=$WHITE              \
                                      label=$LOADING                           \
                                      click_script="open /System/Applications/Mail.app" \
                                      script="$PLUGIN_DIR/mail-indicator.sh"

