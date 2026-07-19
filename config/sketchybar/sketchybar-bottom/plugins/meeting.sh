#!/bin/bash

NEXT_MEETING=$(icalBuddy -ic Cloudera -n -nc -nrd -npn -ea -ps '/ at /' -b '' -iep 'title,datetime' eventsToday | head -1 | rev | cut -d "-" -f2- | rev)
MEETING=${NEXT_MEETING:="No More Meetings!"}
sketchybar-bottom --set $NAME label="${MEETING}"
