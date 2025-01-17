#!/bin/bash

sketchybar --add       item           github.commits right                                  \
           --set       github.commits update_freq=1000                                      \
                                      icon.highlight_color=$WHITE                           \
                                      icon=$GIT_INDICATOR                                   \
                                      label=$LOADING                                        \
                                      click_script="open https://github.com/nandakumar131"  \
                                      script="$PLUGIN_DIR/github-indicator.sh"

