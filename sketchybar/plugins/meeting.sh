#!/bin/bash

NEXT_MEETING=$(icalBuddy -ic Cloudera -n -nc -nrd -npn -ea -ps '/ | /' -b '' -iep 'title,datetime' eventsToday | head -1 | rev | cut -d "-" -f2- | rev)

sketchybar --set $NAME label=${NEXT_MEETING:="No More Meetings!"}
