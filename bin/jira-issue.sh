#!/usr/bin/env bash

set -u

SCRIPT_VERSION="1.0"
PROGRAM_NAME=${0##*/}

# Required environment variables:
#   JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN

# Enable colors/gum styling only when stdout is an interactive terminal. Set
# FORCE_COLOR=1 to keep it when piping, or NO_COLOR=1 to disable explicitly.
USE_COLOR=0
if [[ -z "${NO_COLOR:-}" && ( -t 1 || "${FORCE_COLOR:-0}" == "1" ) ]]; then
  USE_COLOR=1
fi

usage() {
  cat <<USAGE
Usage:
  $PROGRAM_NAME [ISSUE_KEY]

Show a single Jira issue: summary, status, labels, description, and
subtasks. With no ISSUE_KEY, lists your own unresolved issues and lets you
pick one interactively (gum filter if installed and colors are on, fzf
otherwise).

Examples:
  $PROGRAM_NAME
  $PROGRAM_NAME ABC-123

Environment:
  JIRA_URL          e.g. https://example.atlassian.net
  JIRA_USERNAME     Jira login email/username
  JIRA_API_TOKEN    Jira API token/password
  NO_COLOR          set to 1 to disable ANSI colors/gum styling
  FORCE_COLOR       set to 1 to force colors when piped
USAGE
}

fail() {
  if (( USE_COLOR == 1 )); then
    printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  else
    printf 'ERROR: %s\n' "$*" >&2
  fi
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

use_gum() {
  (( USE_COLOR == 1 )) && command -v gum >/dev/null 2>&1
}

# TSV of the current user's unresolved issues: key, status, summary.
list_my_issues() {
  curl -fsS -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
    -G "${JIRA_URL%/}/rest/api/2/search" \
    --data-urlencode 'jql=assignee = currentUser() AND resolution = Unresolved ORDER BY updated DESC' \
    --data-urlencode 'fields=key,summary,status' \
    --data-urlencode 'maxResults=100' \
  | jq -r '.issues[] | [.key, .fields.status.name, .fields.summary] | @tsv'
}

pick_issue_key() {
  local issues
  issues=$(list_my_issues) || fail 'Unable to fetch your Jira issues'
  [[ -n "$issues" ]] || fail 'No unresolved Jira issues assigned to you'

  if use_gum; then
    column -ts $'\t' <<<"$issues" \
      | gum filter --placeholder 'Choose Jira issue…' --height 15 --header 'Choose Jira' \
      | awk '{print $1}'
  else
    require_command fzf
    column -ts $'\t' <<<"$issues" \
      | fzf --border=rounded --no-sort --height 50% --reverse --header='Choose Jira' \
      | awk '{print $1}'
  fi
}

print_issue() {
  local details=$1
  local key summary issue_status labels description subtasks

  key=$(jq -r '.key' <<<"$details")
  summary=$(jq -r '.fields.summary // "-"' <<<"$details")
  issue_status=$(jq -r '.fields.status.name // "-"' <<<"$details")
  labels=$(jq -r '(.fields.labels // []) | join(", ")' <<<"$details")
  labels=${labels:-none}
  description=$(jq -r '.fields.description // "No description."' <<<"$details")
  subtasks=$(jq -r '.fields.subtasks[]? | [.key, .fields.summary] | @tsv' <<<"$details")

  if use_gum; then
    gum style --border rounded --border-foreground 212 --padding '0 2' \
      "$(gum style --bold --foreground 212 "$key")  $(gum style --faint "[$issue_status]")" \
      "$summary" \
      "$(gum style --faint "Labels: $labels")"

    echo
    gum style --bold --underline --foreground 212 'Description'
    printf '%s\n' "$description"

    if [[ -n "$subtasks" ]]; then
      echo
      gum style --bold --underline --foreground 212 'Subtasks'
      gum table --print --separator $'\t' --columns 'Key,Summary' <<<"$subtasks"
    fi
  else
    printf -- '-------------------------------------------\n'
    printf 'ID       %s\n' "$key"
    printf 'Status   %s\n' "$issue_status"
    printf 'Summary  %s\n' "$summary"
    printf 'Labels   %s\n' "$labels"
    printf '\nDescription\n%s\n' "$description"
    if [[ -n "$subtasks" ]]; then
      printf '\nSubtasks\n%s\n' "$subtasks"
    fi
    printf -- '-------------------------------------------\n'
  fi
}

main() {
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --version)
      printf '%s %s\n' "$PROGRAM_NAME" "$SCRIPT_VERSION"
      exit 0
      ;;
  esac

  require_command curl
  require_command jq
  require_command awk
  require_command column

  : "${JIRA_URL:?Set JIRA_URL}"
  : "${JIRA_USERNAME:?Set JIRA_USERNAME}"
  : "${JIRA_API_TOKEN:?Set JIRA_API_TOKEN}"

  local jira_key=${1:-}

  if [[ -z "$jira_key" ]]; then
    jira_key=$(pick_issue_key)
  fi

  [[ -n "$jira_key" ]] || exit 0

  local details
  details=$(
    curl -fsS -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
      "${JIRA_URL%/}/rest/api/latest/issue/${jira_key}?fields=summary,status,labels,description,subtasks"
  ) || fail "Jira request failed for issue $jira_key"

  jq -e . >/dev/null 2>&1 <<<"$details" || fail 'Jira returned invalid JSON'

  if jq -e 'has("errorMessages")' >/dev/null <<<"$details"; then
    jq -r '.errorMessages[]?' <<<"$details" >&2
    exit 1
  fi

  print_issue "$details"
}

main "$@"
