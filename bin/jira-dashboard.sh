#!/usr/bin/env bash

set -u

SCRIPT_VERSION="2.5"
PROGRAM_NAME=${0##*/}

# Required environment variables:
#   JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN
#
# Map a short nickname to each teammate's Jira username/account ID.
#
# Format: "nickname=jira-user"
# Keep the special currentUser() expression for your own account.
# Nicknames must not contain spaces, commas, or '='.
JIRA_TEAM_MEMBERS=(
  "me=currentUser()"
  "ahmar=ahmar@uber.com"
  "deepika=dchoudhary@uber.com"
  "jai=jai.bhobe@uber.com"
  "mayank=mayank.rastogi@uber.com"
  "simhadri=simhadrig@uber.com"
)

JIRA_API_VERSION="${JIRA_API_VERSION:-2}"
PAGE_SIZE="${JIRA_PAGE_SIZE:-100}"
SUMMARY_WIDTH="${JIRA_SUMMARY_WIDTH:-72}"

# Enable colors only when stdout is an interactive terminal. Set FORCE_COLOR=1
# to keep colors when piping, or NO_COLOR=1 to disable them explicitly.
USE_COLOR=0
if [[ -z "${NO_COLOR:-}" && ( -t 1 || "${FORCE_COLOR:-0}" == "1" ) ]]; then
  USE_COLOR=1
fi

usage() {
  cat <<USAGE
Usage:
  $PROGRAM_NAME [--mine | --team | --member NICKNAME]
                [--sprint SPRINT] [--project KEY] [--jql JQL]
                [--summary-only] [--watch SECONDS]
                [--plain | --dashboard]

Examples:
  $PROGRAM_NAME --mine
  $PROGRAM_NAME --team
  $PROGRAM_NAME --member alice
  $PROGRAM_NAME --member alice --member bob
  $PROGRAM_NAME --member alice,bob --sprint 'Sprint 42'
  $PROGRAM_NAME --team --sprint 1234
  $PROGRAM_NAME --team --project HDFS
  $PROGRAM_NAME --team --jql 'priority in (Highest, High)'
  $PROGRAM_NAME --team --watch 60
  $PROGRAM_NAME --team --plain | grep HDFS
  $PROGRAM_NAME --team | awk -F '\t' '$3 == "In Progress"'

Filters:
  --mine               Only issues assigned to currentUser()
  --team               Issues for everyone in JIRA_TEAM_MEMBERS (default)
  --member NICKNAME    Filter by configured nickname. Repeat it or pass a
                       comma-separated list to include multiple teammates.
  --sprint SPRINT      Filter by sprint name or numeric sprint ID
  --project KEY        Filter by Jira project key
  --jql JQL            Add an arbitrary JQL expression
  --summary-only       Hide the detailed issue table
  --watch SECONDS      Continuously refresh the dashboard
  --plain, --script,
  --tsv                Emit issue rows as tab-separated values only. No
                       banner, headings, summaries, borders, or colors.
  --dashboard          Force the full dashboard when stdout is piped or
                       redirected. By default, non-terminal output is TSV.
  --list-members       Print configured nickname mappings and exit
  --version            Print script version and exit

Environment:
  JIRA_URL             e.g. https://example.atlassian.net
  JIRA_USERNAME        Jira login email/username
  JIRA_API_TOKEN       Jira API token/password
  JIRA_API_VERSION     REST API version; default: 2
  JIRA_PAGE_SIZE       issues fetched per request; default: 100
  JIRA_SUMMARY_WIDTH   maximum summary length; default: 72
  NO_COLOR             set to 1 to disable ANSI colors
  FORCE_COLOR          set to 1 to force colors in dashboard mode

Plain TSV fields:
  assignee, key, status, priority, updated, summary
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

# Run "$@" with a gum spinner when gum is installed and output is an
# interactive, colored terminal; otherwise run it directly. The wrapped
# command still runs in this shell (backgrounded, not re-exec'd), so it
# keeps access to this script's functions/variables and its own error
# output still reaches the terminal.
run_with_spinner() {
  local title=$1
  shift

  if (( USE_COLOR == 1 )) && command -v gum >/dev/null 2>&1; then
    "$@" &
    local pid=$!
    gum spin --spinner dot --title "$title" -- bash -c "while kill -0 $pid 2>/dev/null; do sleep 0.2; done"
    wait "$pid"
    return $?
  fi

  "$@"
}

repeat_text() {
  local text=$1
  local count=$2
  local result=''

  while (( count > 0 )); do
    result+="$text"
    count=$((count - 1))
  done

  printf '%s' "$result"
}

# Render tab-separated input as a Unicode bordered table. Coloring is applied
# after widths are calculated, so ANSI escape sequences do not disturb alignment.
render_tsv_table() {
  local title=$1
  local theme=$2

  awk -F '\t' -v title="$title" -v theme="$theme" -v use_color="$USE_COLOR" '
    function repeat_char(char, count, result, i) {
      result = ""
      for (i = 0; i < count; i++) result = result char
      return result
    }

    function paint(code, text) {
      if (!use_color) return text
      return sprintf("\033[%sm%s\033[0m", code, text)
    }

    function status_color(text, lowered) {
      lowered = tolower(text)
      if (lowered ~ /(blocked|impediment|failed|cancelled)/) return "1;91"
      if (lowered ~ /(done|resolved|closed|complete)/) return "1;92"
      if (lowered ~ /(progress|develop|review|testing)/) return "1;93"
      if (lowered ~ /(backlog|open|new|todo|to do)/) return "1;96"
      return "1;95"
    }

    function styled_cell(row, col, raw, padded, heading) {
      padded = sprintf("%-*s", widths[col], raw)
      heading = data[1, col]

      if (row == 1) return paint("1;97", padded)

      if (theme == "summary") {
        if (heading == "ASSIGNEE") return paint("1;96", padded)
        if (heading == "TOTAL") return paint("1;97", padded)
        if (heading == "TO_DO") return paint("1;96", padded)
        if (heading == "IN_PROGRESS") return paint("1;93", padded)
        if (heading == "OTHER") return paint("1;95", padded)
        if (heading == "OLDEST_UPDATE") return paint("2;37", padded)
      }

      if (theme == "status") {
        if (heading == "STATUS") return paint(status_color(raw), padded)
        if (heading == "COUNT") return paint("1;97", padded)
      }

      if (theme == "issues") {
        if (heading == "ASSIGNEE") return paint("1;96", padded)
        if (heading == "KEY") return paint("1;94", padded)
        if (heading == "STATUS") return paint(status_color(raw), padded)
        if (heading == "PRIORITY") {
          if (tolower(raw) ~ /(highest|high|critical|blocker)/) return paint("1;91", padded)
          if (tolower(raw) ~ /(medium|major)/) return paint("1;93", padded)
          if (tolower(raw) ~ /(low|lowest|minor)/) return paint("1;92", padded)
          return paint("1;97", padded)
        }
        if (heading == "UPDATED") return paint("2;37", padded)
      }

      if (theme == "members" && heading == "NICKNAME") return paint("1;96", padded)
      return padded
    }

    function print_border(left, middle, right, i, line) {
      line = left
      for (i = 1; i <= columns; i++) {
        line = line repeat_char("─", widths[i] + 2)
        line = line (i < columns ? middle : right)
      }
      print paint("36", line)
    }

    {
      rows = NR
      if (NF > columns) columns = NF
      for (i = 1; i <= NF; i++) {
        gsub(/\r/, "", $i)
        data[NR, i] = $i
        if (length($i) > widths[i]) widths[i] = length($i)
      }
    }

    END {
      if (rows == 0) exit

      print ""
      print paint("1;96", title)
      print_border("┌", "┬", "┐")

      for (row = 1; row <= rows; row++) {
        if (use_color) printf "\033[36m│\033[0m"
        else printf "│"

        for (col = 1; col <= columns; col++) {
          raw = ((row SUBSEP col) in data ? data[row, col] : "")
          printf " %s ", styled_cell(row, col, raw)

          if (use_color) printf "\033[36m│\033[0m"
          else printf "│"
        }
        printf "\n"

        if (row == 1 && rows > 1) print_border("├", "┼", "┤")
      }

      print_border("└", "┴", "┘")
    }
  '
}

print_banner() {
  local generated=$1
  local issue_count=$2
  local inner_width=70
  local line title metadata

  title='JIRA TEAM DASHBOARD'
  metadata="Generated: $generated   Open issues: $issue_count"

  if (( USE_COLOR == 1 )) && command -v gum >/dev/null 2>&1; then
    gum style --border rounded --border-foreground 51 --padding '0 2' \
      "$(gum style --bold --foreground 231 "$title")" \
      "$(gum style --faint "$metadata")"
    return
  fi

  line=$(repeat_text '─' "$inner_width")

  if (( USE_COLOR == 1 )); then
    printf '\033[36m╭%s╮\033[0m\n' "$line"
    printf '\033[36m│\033[0m \033[1;97m%-68s\033[0m \033[36m│\033[0m\n' "$title"
    printf '\033[36m│\033[0m \033[2;37m%-68s\033[0m \033[36m│\033[0m\n' "$metadata"
    printf '\033[36m╰%s╯\033[0m\n' "$line"
  else
    printf '╭%s╮\n' "$line"
    printf '│ %-68s │\n' "$title"
    printf '│ %-68s │\n' "$metadata"
    printf '╰%s╯\n' "$line"
  fi
}

print_message_box() {
  local message=$1
  local width=${#message}
  local line

  if (( USE_COLOR == 1 )) && command -v gum >/dev/null 2>&1; then
    printf '\n'
    gum style --border rounded --border-foreground 51 --padding '0 2' --foreground 221 "$message"
    return
  fi

  (( width < 36 )) && width=36
  line=$(repeat_text '─' "$((width + 2))")

  if (( USE_COLOR == 1 )); then
    printf '\n\033[36m┌%s┐\033[0m\n' "$line"
    printf '\033[36m│\033[0m \033[1;93m%-*s\033[0m \033[36m│\033[0m\n' "$width" "$message"
    printf '\033[36m└%s┘\033[0m\n' "$line"
  else
    printf '\n┌%s┐\n' "$line"
    printf '│ %-*s │\n' "$width" "$message"
    printf '└%s┘\n' "$line"
  fi
}

jql_quote() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

jql_name_or_numeric_id() {
  local value=$1

  if [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%s' "$value"
  else
    jql_quote "$value"
  fi
}

member_username() {
  local wanted_nickname=$1
  local entry nickname username

  for entry in "${JIRA_TEAM_MEMBERS[@]}"; do
    nickname=${entry%%=*}
    username=${entry#*=}

    if [[ "$nickname" == "$wanted_nickname" ]]; then
      [[ -n "$username" && "$username" != "$entry" ]] || \
        fail "Invalid JIRA_TEAM_MEMBERS entry for nickname: $nickname"
      printf '%s' "$username"
      return 0
    fi
  done

  return 1
}

list_members() {
  local entry nickname username

  {
    printf 'NICKNAME\tJIRA_USER\n'
    for entry in "${JIRA_TEAM_MEMBERS[@]}"; do
      nickname=${entry%%=*}
      username=${entry#*=}
      [[ -n "$nickname" && -n "$username" && "$username" != "$entry" ]] || \
        fail "Invalid JIRA_TEAM_MEMBERS entry: $entry"
      printf '%s\t%s\n' "$nickname" "$username"
    done
  } | render_tsv_table 'CONFIGURED TEAM MEMBERS' 'members'
}

append_unique_member() {
  local nickname=$1
  local current

  [[ -n "$nickname" ]] || fail '--member contains an empty nickname'

  for current in "${SELECTED_MEMBERS[@]-}"; do
    [[ "$current" == "$nickname" ]] && return
  done

  SELECTED_MEMBERS+=("$nickname")
}

parse_member_argument() {
  local value=$1
  local nickname
  local old_ifs=$IFS

  IFS=','
  for nickname in $value; do
    append_unique_member "$nickname"
  done
  IFS=$old_ifs
}

build_assignee_clause() {
  local mode=$1
  local result=''
  local nickname user operand entry

  if [[ "$mode" == "mine" ]]; then
    printf 'assignee = currentUser()'
    return
  fi

  if [[ "$mode" == "members" ]]; then
    for nickname in "${SELECTED_MEMBERS[@]}"; do
      user=$(member_username "$nickname") || \
        fail "Unknown team member nickname: $nickname. Use --list-members to see valid nicknames."

      if [[ "$user" == "currentUser()" ]]; then
        operand='currentUser()'
      else
        operand=$(jql_quote "$user")
      fi

      if [[ -n "$result" ]]; then
        result+=', '
      fi
      result+="$operand"
    done
  else
    for entry in "${JIRA_TEAM_MEMBERS[@]}"; do
      nickname=${entry%%=*}
      user=${entry#*=}
      [[ -n "$nickname" && -n "$user" && "$user" != "$entry" ]] || \
        fail "Invalid JIRA_TEAM_MEMBERS entry: $entry"

      if [[ "$user" == "currentUser()" ]]; then
        operand='currentUser()'
      else
        operand=$(jql_quote "$user")
      fi

      if [[ -n "$result" ]]; then
        result+=', '
      fi
      result+="$operand"
    done
  fi

  [[ -n "$result" ]] || fail 'No Jira team members selected or configured'
  printf 'assignee in (%s)' "$result"
}

fetch_issues() {
  local jql=$1
  local output_file=$2
  local api_url="${JIRA_URL%/}/rest/api/${JIRA_API_VERSION}/search"
  local start_at=0
  local count total response

  : > "$output_file"

  while :; do
    response=$(
      curl -fsS \
        -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        -H 'Accept: application/json' \
        -G "$api_url" \
        --data-urlencode "jql=$jql" \
        --data-urlencode 'fields=key,summary,status,assignee,priority,updated,issuetype,project' \
        --data-urlencode "startAt=$start_at" \
        --data-urlencode "maxResults=$PAGE_SIZE"
    ) || fail "Jira request failed for $api_url"

    jq -e . >/dev/null 2>&1 <<<"$response" || fail 'Jira returned invalid JSON'

    if jq -e '(.errorMessages // []) | length > 0' >/dev/null <<<"$response"; then
      jq -r '.errorMessages[]' <<<"$response" >&2
      return 1
    fi

    jq -c '.issues[]?' <<<"$response" >> "$output_file"

    count=$(jq '.issues | length' <<<"$response")
    total=$(jq '.total // 0' <<<"$response")
    start_at=$((start_at + count))

    (( count == 0 || start_at >= total )) && break
  done
}


print_plain_issues() {
  local issues_file=$1

  [[ -s "$issues_file" ]] || return 0

  jq -sr '
    (
      sort_by((.fields.assignee.displayName // "Unassigned") | ascii_downcase)
      | group_by((.fields.assignee.displayName // "Unassigned") | ascii_downcase)[]
      | sort_by(.fields.updated)
      | reverse[]
      | [
          (.fields.assignee.displayName // "Unassigned"),
          .key,
          (.fields.status.name // "-"),
          (.fields.priority.name // "-"),
          (.fields.updated // "-"),
          ((.fields.summary // "") | gsub("[\\r\\n\\t]+"; " "))
        ]
    )
    | @tsv
  ' "$issues_file"
}

print_dashboard() {
  local issues_file=$1
  local summary_only=$2
  local plain_mode=$3
  local generated issue_count

  if [[ "$plain_mode" == "1" ]]; then
    print_plain_issues "$issues_file"
    return
  fi

  generated=$(date '+%Y-%m-%d %H:%M:%S')
  issue_count=$(jq -s 'length' "$issues_file")

  print_banner "$generated" "$issue_count"

  if [[ ! -s "$issues_file" ]]; then
    print_message_box 'No matching unresolved Jira issues.'
    return
  fi

  jq -sr '
    def category:
      (.fields.status.statusCategory.key // "other");

    ["ASSIGNEE", "TOTAL", "TO_DO", "IN_PROGRESS", "OTHER", "OLDEST_UPDATE"],
    (
      sort_by(.fields.assignee.displayName // "Unassigned")
      | group_by(.fields.assignee.displayName // "Unassigned")[]
      | [
          (.[0].fields.assignee.displayName // "Unassigned"),
          length,
          (map(select(category == "new")) | length),
          (map(select(category == "indeterminate")) | length),
          (map(select(category != "new" and category != "indeterminate")) | length),
          (min_by(.fields.updated).fields.updated[0:10])
        ]
    )
    | @tsv
  ' "$issues_file" | render_tsv_table 'TEAM SUMMARY' 'summary'

  jq -sr '
    ["STATUS", "COUNT"],
    (
      sort_by(.fields.status.name)
      | group_by(.fields.status.name)[]
      | [.[0].fields.status.name, length]
    )
    | @tsv
  ' "$issues_file" | render_tsv_table 'STATUS BREAKDOWN' 'status'

  [[ "$summary_only" == "1" ]] && return

  jq -sr --argjson summary_width "$SUMMARY_WIDTH" '
    def clip($n):
      tostring
      | if length > $n then .[0:($n - 3)] + "..." else . end;

    ["ASSIGNEE", "KEY", "STATUS", "PRIORITY", "UPDATED", "SUMMARY"],
    (
      sort_by((.fields.assignee.displayName // "Unassigned") | ascii_downcase)
      | group_by((.fields.assignee.displayName // "Unassigned") | ascii_downcase)[]
      | sort_by(.fields.updated)
      | reverse[]
      | [
          ((.fields.assignee.displayName // "Unassigned") | clip(22)),
          .key,
          (.fields.status.name | clip(20)),
          (.fields.priority.name // "-"),
          .fields.updated[0:10],
          (.fields.summary | gsub("[\\r\\n\\t]+"; " ") | clip($summary_width))
        ]
    )
    | @tsv
  ' "$issues_file" | render_tsv_table 'ISSUES — GROUPED BY ASSIGNEE, NEWEST FIRST' 'issues'
}

render_once() {
  local mode=$1
  local project=$2
  local sprint=$3
  local extra_jql=$4
  local summary_only=$5
  local plain_mode=$6
  local tmp_file assignee_clause jql

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/jira-dashboard.XXXXXX") || fail 'Unable to create temporary file'
  trap 'rm -f "$tmp_file"' RETURN

  assignee_clause=$(build_assignee_clause "$mode") || fail 'Unable to build assignee filter'
  jql="$assignee_clause AND resolution = Unresolved"

  if [[ -n "$project" ]]; then
    jql+=" AND project = $(jql_quote "$project")"
  fi

  if [[ -n "$sprint" ]]; then
    jql+=" AND sprint = $(jql_name_or_numeric_id "$sprint")"
  fi

  if [[ -n "$extra_jql" ]]; then
    jql+=" AND ($extra_jql)"
  fi

  jql+=' ORDER BY assignee ASC, updated DESC'

  run_with_spinner 'Fetching Jira issues…' fetch_issues "$jql" "$tmp_file" || fail 'Jira search failed'
  print_dashboard "$tmp_file" "$summary_only" "$plain_mode"
  rm -f "$tmp_file"
  trap - RETURN
}

main() {
  local mode='team'
  local project=''
  local sprint=''
  local extra_jql=''
  local summary_only=0
  local watch_seconds=0
  local show_members=0
  local output_mode=auto
  local plain_mode=0

  # Global for compatibility with Bash 3.2, which remains common on macOS.
  SELECTED_MEMBERS=()

  while (( $# > 0 )); do
    case "$1" in
      --mine)
        mode='mine'
        ;;
      --team)
        mode='team'
        ;;
      --member|--team-member)
        (( $# >= 2 )) || fail "$1 requires a nickname"
        mode='members'
        parse_member_argument "$2"
        shift
        ;;
      --sprint)
        (( $# >= 2 )) || fail '--sprint requires a sprint name or ID'
        sprint=$2
        shift
        ;;
      --project)
        (( $# >= 2 )) || fail '--project requires a value'
        project=$2
        shift
        ;;
      --jql)
        (( $# >= 2 )) || fail '--jql requires a value'
        extra_jql=$2
        shift
        ;;
      --summary-only)
        summary_only=1
        ;;
      --plain|--script|--tsv)
        output_mode=plain
        ;;
      --dashboard)
        output_mode=dashboard
        ;;
      --watch)
        (( $# >= 2 )) || fail '--watch requires seconds'
        watch_seconds=$2
        [[ "$watch_seconds" =~ ^[1-9][0-9]*$ ]] || fail '--watch must be a positive integer'
        shift
        ;;
      --list-members)
        show_members=1
        ;;
      --version)
        printf 'jira-dashboard %s\n' "$SCRIPT_VERSION"
        exit 0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown option: $1"
        ;;
    esac
    shift
  done

  require_command curl
  require_command jq
  require_command awk

  case "$output_mode" in
    plain) plain_mode=1 ;;
    dashboard) plain_mode=0 ;;
    auto)
      if [[ -t 1 ]]; then plain_mode=0; else plain_mode=1; fi
      ;;
  esac

  if (( plain_mode == 1 )); then
    USE_COLOR=0
  fi

  if (( watch_seconds > 0 && plain_mode == 1 )); then
    fail '--watch requires dashboard output; add --dashboard or remove --watch'
  fi

  if (( show_members == 1 )); then
    list_members
    exit 0
  fi

  if [[ "$mode" == "members" && -z "${SELECTED_MEMBERS[0]+set}" ]]; then
    fail '--member requires at least one nickname'
  fi

  : "${JIRA_URL:?Set JIRA_URL}"
  : "${JIRA_USERNAME:?Set JIRA_USERNAME}"
  : "${JIRA_API_TOKEN:?Set JIRA_API_TOKEN}"

  if (( watch_seconds > 0 )); then
    while :; do
      clear
      render_once "$mode" "$project" "$sprint" "$extra_jql" "$summary_only" "$plain_mode"
      if (( USE_COLOR == 1 )); then
        printf '\n\033[2;37mRefreshing every %s seconds. Press Ctrl-C to stop.\033[0m\n' "$watch_seconds"
      else
        printf '\nRefreshing every %s seconds. Press Ctrl-C to stop.\n' "$watch_seconds"
      fi
      sleep "$watch_seconds"
    done
  else
    render_once "$mode" "$project" "$sprint" "$extra_jql" "$summary_only" "$plain_mode"
  fi
}

main "$@"
