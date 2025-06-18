#!/bin/bash

sketchybar-bottom --add       item           github.notification right                                  \
           --set       github.notification update_freq=300                                       \
                                      icon.highlight_color=$WHITE                           \
                                      icon=󱅫						\
                                      label=$LOADING                                        \
                                      click_script="osascript -e 'tell application \"Arc\" to make new tab with properties {URL: \"http://github.com/notifications\"}'" \
                                      script="$PLUGIN_DIR/github-notification.sh"

