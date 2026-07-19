#!/bin/bash

sketchybar-bottom --add       item           github.commits right                                  \
           --set       github.commits  update_freq=300                                       \
                                      icon.highlight_color=$WHITE                           \
                                      icon=$GIT_INDICATOR                                   \
                                      label=$LOADING                                        \
                                      click_script="osascript -e 'tell application \"Arc\" to make new tab with properties {URL: \"http://github.com/nandakumar131\"}'" \
                                      script="$PLUGIN_DIR/github-indicator.sh"

