#!/usr/bin/env bash

# Read the matched text from tmux-fingers
MATCH=$(cat)

. ~/.config/zsh/zshrc.local 2>/dev/null

if [ $(uname) = "Darwin" ]; then
    Launcher="open"
else
    Launcher="xdg-open"
fi

if echo "$MATCH" | grep -Eq '^https?://'; then
    # It's a web link: Open in browser
    $Launcher "$MATCH"
elif echo "$MATCH" | grep -Eq '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
    # It's an email: Open email client
    $Launcher "mailto:$MATCH"
elif echo "$MATCH" | grep -Eq '(HDFS|HINFRA|DEPENDREQ|UPA|URP|PLANPLAT|DLM|CLOUDMIG|SSD40M|TSTPGM|YARNRED|HDFSRED|SO|IAM)-(\d+)'; then
    # It's jira: Open in browser
    $Launcher "$JIRA_BASE_URL/browse/$MATCH"
elif echo "$MATCH" | grep -Eq '(\d{9})'; then
    # It's Incident: Open in browser
    $Launcher "$PAGERDUTY_BASE_URL/incidents/$MATCH"
else
    # Default action: Just copy to system clipboard
    echo "$MATCH" | xclip -selection clipboard 2>/dev/null || echo "$MATCH" | pbcopy
fi

