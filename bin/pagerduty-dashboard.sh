#!/usr/bin/env bash

set -u

SCRIPT_VERSION="1.5"
PROGRAM_NAME=${0##*/}

# Required environment variable:
#   PAGERDUTY_API_TOKEN
#
# Map a short nickname to each teammate's PagerDuty user ID.
# Find the ID in the PagerDuty user URL or with the PagerDuty Users API.
#
# Format: "nickname=PAGERDUTY_USER_ID"
# Nicknames must not contain spaces, commas, or '='.
PAGERDUTY_TEAM_MEMBERS=(
  "me=PD92U1N"
  "jyoti=P9MUPCY"
)

# Nickname selected by --mine.
PAGERDUTY_ME_NICKNAME="${PAGERDUTY_ME_NICKNAME:-me}"

# US: https://api.pagerduty.com
# EU: https://api.eu.pagerduty.com
PAGERDUTY_API_URL="${PAGERDUTY_API_URL:-https://api.pagerduty.com}"
PAGERDUTY_PAGE_SIZE="${PAGERDUTY_PAGE_SIZE:-100}"
PAGERDUTY_TITLE_WIDTH="${PAGERDUTY_TITLE_WIDTH:-68}"
PAGERDUTY_AUTH_SCHEME="${PAGERDUTY_AUTH_SCHEME:-token}"

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
                [--status STATUS] [--urgency URGENCY]
                [--service-id ID] [--team-id ID]
                [--since ISO8601] [--until ISO8601]
                [--summary-only] [--watch SECONDS]
                [--plain | --dashboard]

Examples:
  $PROGRAM_NAME --mine
  $PROGRAM_NAME --team
  $PROGRAM_NAME --member alice
  $PROGRAM_NAME --member alice --member bob
  $PROGRAM_NAME --member alice,bob --status triggered
  $PROGRAM_NAME --team --urgency high
  $PROGRAM_NAME --team --service-id PXXXXXX
  $PROGRAM_NAME --team --team-id PYYYYYY
  $PROGRAM_NAME --team --since '2026-07-01T00:00:00Z'
  $PROGRAM_NAME --team --watch 60
  $PROGRAM_NAME --team --plain | grep triggered
  $PROGRAM_NAME --team | awk -F '\t' '$3 == "triggered"'

Assignee selection:
  --mine               Incidents assigned to PAGERDUTY_ME_NICKNAME
  --team               Incidents assigned to all configured members (default)
  --member NICKNAME    Select a configured nickname. Repeat it or pass a
                       comma-separated list to include multiple teammates.

Incident filters:
  --status STATUS      active, triggered, or acknowledged. Repeat or use commas.
                       Default: active (triggered and acknowledged)
  --urgency URGENCY    high or low. Repeat or use commas. Default: both
  --service-id ID      Filter by PagerDuty service ID. Repeat or use commas
  --team-id ID         Filter by PagerDuty team ID. Repeat or use commas
  --since ISO8601      Start of incident creation range
  --until ISO8601      End of incident creation range

Display:
  --summary-only       Hide the detailed incident table
  --watch SECONDS      Continuously refresh the dashboard
  --plain, --script,
  --tsv                Emit incident rows as tab-separated values only. No
                       banner, headings, summaries, borders, or colors.
  --dashboard          Force the full dashboard when stdout is piped or
                       redirected. By default, non-terminal output is TSV.
  --list-members       Print configured nickname mappings and exit
  --version            Print script version and exit

Environment:
  PAGERDUTY_API_TOKEN      PagerDuty REST API token
  PAGERDUTY_API_URL        Default: https://api.pagerduty.com
                           EU: https://api.eu.pagerduty.com
  PAGERDUTY_AUTH_SCHEME    token (default) or bearer for OAuth
  PAGERDUTY_ME_NICKNAME    Nickname used by --mine; default: me
  PAGERDUTY_PAGE_SIZE      Results per request; default/max: 100
  PAGERDUTY_TITLE_WIDTH    Maximum incident title length; default: 68
  NO_COLOR                 Set to 1 to disable ANSI colors
  FORCE_COLOR              Set to 1 to force colors in dashboard mode

Plain TSV fields:
  assignee, incident, status, urgency, age, title
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
      if (lowered == "triggered") return "1;91"
      if (lowered == "acknowledged") return "1;93"
      if (lowered == "resolved") return "1;92"
      return "1;95"
    }

    function urgency_color(text, lowered) {
      lowered = tolower(text)
      if (lowered == "high") return "1;91"
      if (lowered == "low") return "1;96"
      return "1;97"
    }

    function styled_cell(row, col, raw, padded, heading) {
      padded = sprintf("%-*s", widths[col], raw)
      heading = data[1, col]

      if (row == 1) return paint("1;97", padded)

      if (theme == "summary") {
        if (heading == "ASSIGNEE") return paint("1;96", padded)
        if (heading == "TOTAL") return paint("1;97", padded)
        if (heading == "TRIGGERED") return paint("1;91", padded)
        if (heading == "ACKNOWLEDGED") return paint("1;93", padded)
        if (heading == "HIGH") return paint("1;91", padded)
        if (heading == "LOW") return paint("1;96", padded)
        if (heading == "OLDEST") return paint("2;37", padded)
      }

      if (theme == "status") {
        if (heading == "STATUS") return paint(status_color(raw), padded)
        if (heading == "COUNT") return paint("1;97", padded)
      }

      if (theme == "service") {
        if (heading == "SERVICE") return paint("1;94", padded)
        if (heading == "TOTAL") return paint("1;97", padded)
        if (heading == "TRIGGERED") return paint("1;91", padded)
        if (heading == "ACKNOWLEDGED") return paint("1;93", padded)
        if (heading == "HIGH") return paint("1;91", padded)
      }

      if (theme == "incidents") {
        if (heading == "ASSIGNEE") return paint("1;96", padded)
        if (heading == "INCIDENT") return paint("1;94", padded)
        if (heading == "STATUS") return paint(status_color(raw), padded)
        if (heading == "URGENCY") return paint(urgency_color(raw), padded)
        if (heading == "AGE") return paint("2;37", padded)
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
  local incident_count=$2
  local high_count=$3
  local triggered_count=$4
  local inner_width=76
  local line title metadata

  line=$(repeat_text '─' "$inner_width")
  title='PAGERDUTY TEAM DASHBOARD'
  metadata="Generated: $generated   Active: $incident_count   Triggered: $triggered_count   High: $high_count"

  if (( USE_COLOR == 1 )); then
    printf '\033[36m╭%s╮\033[0m\n' "$line"
    printf '\033[36m│\033[0m \033[1;97m%-74s\033[0m \033[36m│\033[0m\n' "$title"
    printf '\033[36m│\033[0m \033[2;37m%-74s\033[0m \033[36m│\033[0m\n' "$metadata"
    printf '\033[36m╰%s╯\033[0m\n' "$line"
  else
    printf '╭%s╮\n' "$line"
    printf '│ %-74s │\n' "$title"
    printf '│ %-74s │\n' "$metadata"
    printf '╰%s╯\n' "$line"
  fi
}

print_message_box() {
  local message=$1
  local width=${#message}
  local line

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

member_user_id() {
  local wanted_nickname=$1
  local entry nickname user_id

  for entry in "${PAGERDUTY_TEAM_MEMBERS[@]}"; do
    nickname=${entry%%=*}
    user_id=${entry#*=}

    if [[ "$nickname" == "$wanted_nickname" ]]; then
      [[ -n "$user_id" && "$user_id" != "$entry" ]] || \
        fail "Invalid PAGERDUTY_TEAM_MEMBERS entry for nickname: $nickname"
      printf '%s' "$user_id"
      return 0
    fi
  done

  return 1
}

validate_member_entry() {
  local entry=$1
  local nickname=${entry%%=*}
  local user_id=${entry#*=}

  [[ -n "$nickname" && -n "$user_id" && "$user_id" != "$entry" ]] || \
    fail "Invalid PAGERDUTY_TEAM_MEMBERS entry: $entry"
  [[ "$nickname" != *','* && "$nickname" != *' '* ]] || \
    fail "Invalid PagerDuty nickname: $nickname"
}

list_members() {
  local entry nickname user_id

  {
    printf 'NICKNAME\tPAGERDUTY_USER_ID\n'
    for entry in "${PAGERDUTY_TEAM_MEMBERS[@]}"; do
      validate_member_entry "$entry"
      nickname=${entry%%=*}
      user_id=${entry#*=}
      printf '%s\t%s\n' "$nickname" "$user_id"
    done
  } | render_tsv_table 'CONFIGURED TEAM MEMBERS' 'members'
}

append_unique_value() {
  local array_name=$1
  local value=$2
  local current

  [[ -n "$value" ]] || fail "Empty value supplied for $array_name"

  case "$array_name" in
    SELECTED_MEMBERS)
      for current in "${SELECTED_MEMBERS[@]-}"; do
        [[ "$current" == "$value" ]] && return
      done
      SELECTED_MEMBERS+=("$value")
      ;;
    STATUS_FILTERS)
      for current in "${STATUS_FILTERS[@]-}"; do
        [[ "$current" == "$value" ]] && return
      done
      STATUS_FILTERS+=("$value")
      ;;
    URGENCY_FILTERS)
      for current in "${URGENCY_FILTERS[@]-}"; do
        [[ "$current" == "$value" ]] && return
      done
      URGENCY_FILTERS+=("$value")
      ;;
    SERVICE_IDS)
      for current in "${SERVICE_IDS[@]-}"; do
        [[ "$current" == "$value" ]] && return
      done
      SERVICE_IDS+=("$value")
      ;;
    PD_TEAM_IDS)
      for current in "${PD_TEAM_IDS[@]-}"; do
        [[ "$current" == "$value" ]] && return
      done
      PD_TEAM_IDS+=("$value")
      ;;
    SELECTED_USER_IDS)
      for current in "${SELECTED_USER_IDS[@]-}"; do
        [[ "$current" == "$value" ]] && return
      done
      SELECTED_USER_IDS+=("$value")
      ;;
    *)
      fail "Internal error: unsupported array $array_name"
      ;;
  esac
}

parse_csv_argument() {
  local array_name=$1
  local value=$2
  local item
  local old_ifs=$IFS

  IFS=','
  for item in $value; do
    append_unique_value "$array_name" "$item"
  done
  IFS=$old_ifs
}

parse_status_argument() {
  local value=$1
  local item
  local old_ifs=$IFS

  IFS=','
  for item in $value; do
    case "$item" in
      active)
        append_unique_value STATUS_FILTERS triggered
        append_unique_value STATUS_FILTERS acknowledged
        ;;
      triggered|acknowledged)
        append_unique_value STATUS_FILTERS "$item"
        ;;
      resolved)
        fail 'Resolved incidents cannot be filtered by current assignee; use triggered or acknowledged.'
        ;;
      *)
        fail "Invalid --status value: $item"
        ;;
    esac
  done
  IFS=$old_ifs
}

parse_urgency_argument() {
  local value=$1
  local item
  local old_ifs=$IFS

  IFS=','
  for item in $value; do
    case "$item" in
      high|low)
        append_unique_value URGENCY_FILTERS "$item"
        ;;
      all)
        URGENCY_FILTERS=()
        ;;
      *)
        fail "Invalid --urgency value: $item"
        ;;
    esac
  done
  IFS=$old_ifs
}

resolve_selected_users() {
  local mode=$1
  local entry nickname user_id

  SELECTED_USER_IDS=()
  SELECTED_LABEL_PAIRS=()

  if [[ "$mode" == "mine" ]]; then
    SELECTED_MEMBERS=("$PAGERDUTY_ME_NICKNAME")
    mode='members'
  fi

  if [[ "$mode" == "members" ]]; then
    for nickname in "${SELECTED_MEMBERS[@]}"; do
      user_id=$(member_user_id "$nickname") || \
        fail "Unknown PagerDuty nickname: $nickname. Use --list-members to see valid nicknames."
      append_unique_value SELECTED_USER_IDS "$user_id"
      SELECTED_LABEL_PAIRS+=("$user_id=$nickname")
    done
  else
    for entry in "${PAGERDUTY_TEAM_MEMBERS[@]}"; do
      validate_member_entry "$entry"
      nickname=${entry%%=*}
      user_id=${entry#*=}
      append_unique_value SELECTED_USER_IDS "$user_id"
      SELECTED_LABEL_PAIRS+=("$user_id=$nickname")
    done
  fi

  [[ -n "${SELECTED_USER_IDS[0]+set}" ]] || fail 'No PagerDuty team members selected or configured'
}

auth_header_value() {
  case "$PAGERDUTY_AUTH_SCHEME" in
    token)
      printf 'Token token=%s' "$PAGERDUTY_API_TOKEN"
      ;;
    bearer)
      printf 'Bearer %s' "$PAGERDUTY_API_TOKEN"
      ;;
    *)
      fail 'PAGERDUTY_AUTH_SCHEME must be token or bearer'
      ;;
  esac
}

api_error_message() {
  local response_file=$1
  jq -r '
    .error.message //
    .message //
    .error //
    "PagerDuty request failed"
  ' "$response_file" 2>/dev/null || printf 'PagerDuty request failed'
}

fetch_incidents() {
  local output_file=$1
  local since=$2
  local until=$3
  local api_url="${PAGERDUTY_API_URL%/}/incidents"
  local offset=0
  local response_file http_code more count
  local auth_header
  local user_id status urgency service_id team_id
  local -a curl_args

  auth_header=$(auth_header_value)
  : > "$output_file"

  while :; do
    response_file=$(mktemp "${TMPDIR:-/tmp}/pagerduty-response.XXXXXX") || \
      fail 'Unable to create PagerDuty response file'

    curl_args=(
      -sS
      --retry 3
      --retry-delay 2
      --retry-all-errors
      -o "$response_file"
      -w '%{http_code}'
      -G "$api_url"
      -H 'Accept: application/vnd.pagerduty+json;version=2'
      -H "Authorization: $auth_header"
      --data-urlencode "limit=$PAGERDUTY_PAGE_SIZE"
      --data-urlencode "offset=$offset"
      --data-urlencode 'time_zone=UTC'
      --data-urlencode 'sort_by=created_at:desc'
    )

    # The ${ARRAY[@]-} form is required for macOS Bash 3.2 when
    # `set -u` is enabled and an optional array is empty.
    for user_id in "${SELECTED_USER_IDS[@]-}"; do
      [[ -n "$user_id" ]] || continue
      curl_args+=(--data-urlencode "user_ids[]=$user_id")
    done

    for status in "${STATUS_FILTERS[@]-}"; do
      [[ -n "$status" ]] || continue
      curl_args+=(--data-urlencode "statuses[]=$status")
    done

    for urgency in "${URGENCY_FILTERS[@]-}"; do
      [[ -n "$urgency" ]] || continue
      curl_args+=(--data-urlencode "urgencies[]=$urgency")
    done

    for service_id in "${SERVICE_IDS[@]-}"; do
      [[ -n "$service_id" ]] || continue
      curl_args+=(--data-urlencode "service_ids[]=$service_id")
    done

    for team_id in "${PD_TEAM_IDS[@]-}"; do
      [[ -n "$team_id" ]] || continue
      curl_args+=(--data-urlencode "team_ids[]=$team_id")
    done

    if [[ -n "$since" ]]; then
      curl_args+=(--data-urlencode "since=$since")
    fi

    if [[ -n "$until" ]]; then
      curl_args+=(--data-urlencode "until=$until")
    fi

    if [[ -z "$since" && -z "$until" ]]; then
      curl_args+=(--data-urlencode 'date_range=all')
    fi

    http_code=$(curl "${curl_args[@]}") || {
      rm -f "$response_file"
      fail "Unable to connect to $api_url"
    }

    case "$http_code" in
      2??)
        ;;
      *)
        local error_message
        error_message=$(api_error_message "$response_file")
        rm -f "$response_file"
        fail "PagerDuty API returned HTTP $http_code: $error_message"
        ;;
    esac

    jq -e . "$response_file" >/dev/null 2>&1 || {
      rm -f "$response_file"
      fail 'PagerDuty returned invalid JSON'
    }

    jq -c '.incidents[]?' "$response_file" >> "$output_file"

    count=$(jq '.incidents | length' "$response_file")
    more=$(jq -r '.more // false' "$response_file")
    offset=$((offset + count))
    rm -f "$response_file"

    [[ "$more" == "true" && "$count" -gt 0 ]] || break
  done
}

selected_ids_json() {
  printf '%s\n' "${SELECTED_USER_IDS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))'
}

selected_labels_json() {
  printf '%s\n' "${SELECTED_LABEL_PAIRS[@]}" | jq -Rsc '
    split("\n")
    | map(select(length > 0))
    | map(capture("^(?<id>[^=]+)=(?<label>.*)$"))
    | map({key: .id, value: .label})
    | from_entries
  '
}


print_plain_incidents() {
  local incidents_file=$1
  local ids_json labels_json

  [[ -s "$incidents_file" ]] || return 0

  ids_json=$(selected_ids_json)
  labels_json=$(selected_labels_json)

  jq -sr \
    --argjson selected_ids "$ids_json" \
    --argjson labels "$labels_json" '
    def clean_time:
      sub("\\.[0-9]+Z$"; "Z")
      | sub("\\+00:00$"; "Z");

    def epoch:
      clean_time | fromdateiso8601;

    def age_text($timestamp):
      ((now - ($timestamp | epoch)) | floor) as $seconds
      | if $seconds < 0 then "0m"
        elif $seconds < 3600 then (($seconds / 60 | floor | tostring) + "m")
        elif $seconds < 86400 then (($seconds / 3600 | floor | tostring) + "h")
        else (($seconds / 86400 | floor | tostring) + "d")
        end;

    (
      [ .[] as $incident
        | $incident.assignments[]?.assignee as $assignee
        | select($selected_ids | index($assignee.id))
        | {
            assignee: ($labels[$assignee.id] // $assignee.summary // $assignee.id),
            incident: $incident
          }
      ]
      | sort_by(.assignee | ascii_downcase)
      | group_by(.assignee | ascii_downcase)[]
      | sort_by(.incident.updated_at)
      | reverse[]
      | [
          .assignee,
          ("#" + (.incident.incident_number | tostring)),
          (.incident.status // "-"),
          (.incident.urgency // "-"),
          age_text(.incident.created_at),
          ((.incident.title // "") | gsub("[\\r\\n\\t]+"; " "))
        ]
    )
    | @tsv
  ' "$incidents_file"
}

print_dashboard() {
  local incidents_file=$1
  local summary_only=$2
  local plain_mode=$3
  local generated incident_count high_count triggered_count
  local ids_json labels_json

  if [[ "$plain_mode" == "1" ]]; then
    print_plain_incidents "$incidents_file"
    return
  fi

  generated=$(date '+%Y-%m-%d %H:%M:%S')
  incident_count=$(jq -s 'length' "$incidents_file")
  high_count=$(jq -s 'map(select(.urgency == "high")) | length' "$incidents_file")
  triggered_count=$(jq -s 'map(select(.status == "triggered")) | length' "$incidents_file")
  ids_json=$(selected_ids_json)
  labels_json=$(selected_labels_json)

  print_banner "$generated" "$incident_count" "$high_count" "$triggered_count"

  if [[ ! -s "$incidents_file" ]]; then
    print_message_box 'No matching active PagerDuty incidents.'
    return
  fi

  jq -sr --argjson selected_ids "$ids_json" --argjson labels "$labels_json" '
    def clean_time:
      sub("\\.[0-9]+Z$"; "Z")
      | sub("\\+00:00$"; "Z");

    def epoch:
      clean_time | fromdateiso8601;

    def age_text($timestamp):
      ((now - ($timestamp | epoch)) | floor) as $seconds
      | if $seconds < 0 then "0m"
        elif $seconds < 3600 then (($seconds / 60 | floor | tostring) + "m")
        elif $seconds < 86400 then (($seconds / 3600 | floor | tostring) + "h")
        else (($seconds / 86400 | floor | tostring) + "d")
        end;

    def assignee_rows:
      [ .[] as $incident
        | $incident.assignments[]?.assignee as $assignee
        | select($selected_ids | index($assignee.id))
        | {
            assignee: ($labels[$assignee.id] // $assignee.summary // $assignee.id),
            incident: $incident
          }
      ];

    assignee_rows
    | ["ASSIGNEE", "TOTAL", "TRIGGERED", "ACKNOWLEDGED", "HIGH", "LOW", "OLDEST"],
      (
        sort_by(.assignee | ascii_downcase)
        | group_by(.assignee | ascii_downcase)[]
        | [
            .[0].assignee,
            length,
            (map(select(.incident.status == "triggered")) | length),
            (map(select(.incident.status == "acknowledged")) | length),
            (map(select(.incident.urgency == "high")) | length),
            (map(select(.incident.urgency == "low")) | length),
            (min_by(.incident.created_at).incident.created_at | age_text(.))
          ]
      )
    | @tsv
  ' "$incidents_file" | render_tsv_table 'TEAM SUMMARY' 'summary'

  jq -sr '
    ["STATUS", "COUNT"],
    (
      sort_by(.status)
      | group_by(.status)[]
      | [.[0].status, length]
    )
    | @tsv
  ' "$incidents_file" | render_tsv_table 'STATUS BREAKDOWN' 'status'

  jq -sr '
    ["SERVICE", "TOTAL", "TRIGGERED", "ACKNOWLEDGED", "HIGH"],
    (
      sort_by(.service.summary // "Unknown")
      | group_by(.service.summary // "Unknown")[]
      | [
          (.[0].service.summary // "Unknown"),
          length,
          (map(select(.status == "triggered")) | length),
          (map(select(.status == "acknowledged")) | length),
          (map(select(.urgency == "high")) | length)
        ]
    )
    | @tsv
  ' "$incidents_file" | render_tsv_table 'SERVICE BREAKDOWN' 'service'

  [[ "$summary_only" == "1" ]] && return

  jq -sr \
    --argjson selected_ids "$ids_json" \
    --argjson labels "$labels_json" \
    --argjson title_width "$PAGERDUTY_TITLE_WIDTH" '
    def clip($n):
      tostring
      | if length > $n then .[0:($n - 3)] + "..." else . end;

    def clean_time:
      sub("\\.[0-9]+Z$"; "Z")
      | sub("\\+00:00$"; "Z");

    def epoch:
      clean_time | fromdateiso8601;

    def age_text($timestamp):
      ((now - ($timestamp | epoch)) | floor) as $seconds
      | if $seconds < 0 then "0m"
        elif $seconds < 3600 then (($seconds / 60 | floor | tostring) + "m")
        elif $seconds < 86400 then (($seconds / 3600 | floor | tostring) + "h")
        else (($seconds / 86400 | floor | tostring) + "d")
        end;

    ["ASSIGNEE", "INCIDENT", "STATUS", "URGENCY", "AGE", "TITLE"],
    (
      [ .[] as $incident
        | $incident.assignments[]?.assignee as $assignee
        | select($selected_ids | index($assignee.id))
        | {
            assignee: ($labels[$assignee.id] // $assignee.summary // $assignee.id),
            incident: $incident
          }
      ]
      | sort_by(.assignee | ascii_downcase)
      | group_by(.assignee | ascii_downcase)[]
      | sort_by(.incident.updated_at)
      | reverse[]
      | [
          .assignee,
          ("#" + (.incident.incident_number | tostring)),
          .incident.status,
          (.incident.urgency // "-"),
          age_text(.incident.created_at),
          (.incident.title | gsub("[\\r\\n\\t]+"; " ") | clip($title_width))
        ]
    )
    | @tsv
  ' "$incidents_file" | render_tsv_table 'INCIDENTS — GROUPED BY ASSIGNEE, NEWEST UPDATED FIRST' 'incidents'
}

render_once() {
  local mode=$1
  local since=$2
  local until=$3
  local summary_only=$4
  local plain_mode=$5
  local tmp_file

  resolve_selected_users "$mode"

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/pagerduty-dashboard.XXXXXX") || \
    fail 'Unable to create temporary file'

  fetch_incidents "$tmp_file" "$since" "$until"
  print_dashboard "$tmp_file" "$summary_only" "$plain_mode"
  rm -f "$tmp_file"
}

main() {
  local mode='team'
  local since=''
  local until=''
  local summary_only=0
  local watch_seconds=0
  local show_members=0
  local output_mode=auto
  local plain_mode=0

  # Globals are used for Bash 3.2 compatibility on macOS.
  SELECTED_MEMBERS=()
  SELECTED_USER_IDS=()
  SELECTED_LABEL_PAIRS=()
  STATUS_FILTERS=()
  URGENCY_FILTERS=()
  SERVICE_IDS=()
  PD_TEAM_IDS=()

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
        parse_csv_argument SELECTED_MEMBERS "$2"
        shift
        ;;
      --status)
        (( $# >= 2 )) || fail '--status requires active, triggered, or acknowledged'
        parse_status_argument "$2"
        shift
        ;;
      --urgency)
        (( $# >= 2 )) || fail '--urgency requires high or low'
        parse_urgency_argument "$2"
        shift
        ;;
      --service-id)
        (( $# >= 2 )) || fail '--service-id requires a PagerDuty service ID'
        parse_csv_argument SERVICE_IDS "$2"
        shift
        ;;
      --team-id)
        (( $# >= 2 )) || fail '--team-id requires a PagerDuty team ID'
        parse_csv_argument PD_TEAM_IDS "$2"
        shift
        ;;
      --since)
        (( $# >= 2 )) || fail '--since requires an ISO-8601 timestamp'
        since=$2
        shift
        ;;
      --until)
        (( $# >= 2 )) || fail '--until requires an ISO-8601 timestamp'
        until=$2
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
        printf 'pagerduty-dashboard %s\n' "$SCRIPT_VERSION"
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

  [[ "$PAGERDUTY_PAGE_SIZE" =~ ^[1-9][0-9]*$ ]] || \
    fail 'PAGERDUTY_PAGE_SIZE must be a positive integer'
  (( PAGERDUTY_PAGE_SIZE <= 100 )) || \
    fail 'PAGERDUTY_PAGE_SIZE cannot exceed the PagerDuty maximum of 100'

  if (( show_members == 1 )); then
    list_members
    exit 0
  fi

  if [[ "$mode" == "members" && -z "${SELECTED_MEMBERS[0]+set}" ]]; then
    fail '--member requires at least one nickname'
  fi

  if [[ -z "${STATUS_FILTERS[0]+set}" ]]; then
    STATUS_FILTERS=(triggered acknowledged)
  fi

  : "${PAGERDUTY_API_TOKEN:?Set PAGERDUTY_API_TOKEN}"

  if (( watch_seconds > 0 )); then
    while :; do
      clear
      render_once "$mode" "$since" "$until" "$summary_only" "$plain_mode"
      if (( USE_COLOR == 1 )); then
        printf '\n\033[2;37mRefreshing every %s seconds. Press Ctrl-C to stop.\033[0m\n' "$watch_seconds"
      else
        printf '\nRefreshing every %s seconds. Press Ctrl-C to stop.\n' "$watch_seconds"
      fi
      sleep "$watch_seconds"
    done
  else
    render_once "$mode" "$since" "$until" "$summary_only" "$plain_mode"
  fi
}

main "$@"
