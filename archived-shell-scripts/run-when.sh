#!/usr/bin/env bash
# Run a command only if current time is within a day/time window.
# Examples:
#   whenrun.sh --days "Mon..Fri" --start 09:00 --end 17:00 -- gtk-launch com.microsoft.Teams
#   whenrun.sh --days "weekends" --start 10:30 --end 23:00 -- my-app
#   whenrun.sh --days "1,3,5"   --start 08:00 --end 12:00 -- echo "hi"
#
# Days accepted:
#   - Names: Mon,Tue,Wed,Thu,Fri,Sat,SUN (case-insensitive)
#   - Ranges: Mon..Fri, Tue..Sun, 1..5, 5..7
#   - Lists: Mon,Wed,Fri or 1,3,5
#   - Keywords: weekdays (Mon..Fri), weekends (Sat..Sun)
#
# Time window:
#   - 24h HH:MM (e.g., 09:00)
#   - Cross-midnight supported (e.g., --start 22:00 --end 02:00)

set -euo pipefail

DAYS_SPEC="Mon..Fri"
START="09:00"
END="17:00"

# ---- arg parse ----
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [--days SPEC] [--start HH:MM] [--end HH:MM] -- <command...>" >&2
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)  DAYS_SPEC="${2:-}"; shift 2 ;;
    --start) START="${2:-}";     shift 2 ;;
    --end)   END="${2:-}";       shift 2 ;;
    --)      shift; break ;;
    *)       echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ $# -eq 0 ]]; then
  echo "Missing command after --" >&2
  exit 2
fi

CMD=("$@")

# ---- helpers ----
to_num_day() { # mon->1 ... sun->7
  case "${1,,}" in
    1|mon) echo 1 ;;
    2|tue) echo 2 ;;
    3|wed) echo 3 ;;
    4|thu) echo 4 ;;
    5|fri) echo 5 ;;
    6|sat) echo 6 ;;
    7|sun) echo 7 ;;
    *) return 1 ;;
  esac
}

expand_days() {
  local spec="${1,,}"
  spec="${spec// /}"  # strip spaces

  case "$spec" in
    weekdays) spec="mon..fri" ;;
    weekends) spec="sat..sun" ;;
  esac

  local out=()

  if [[ "$spec" =~ ^([a-z]+|[1-7])\.\.([a-z]+|[1-7])$ ]]; then
    # range like mon..fri or 1..5
    local a b i
    a=$(to_num_day "${BASH_REMATCH[1]}") || { echo "bad day: ${BASH_REMATCH[1]}" >&2; exit 2; }
    b=$(to_num_day "${BASH_REMATCH[2]}") || { echo "bad day: ${BASH_REMATCH[2]}" >&2; exit 2; }
    if (( a <= b )); then
      for ((i=a;i<=b;i++)); do out+=("$i"); done
    else
      # wrap (e.g., sun..wed)
      for ((i=a;i<=7;i++)); do out+=("$i"); done
      for ((i=1;i<=b;i++)); do out+=("$i"); done
    fi
  else
    # list like mon,wed,fri or 1,3,5
    IFS=',' read -r -a parts <<< "$spec"
    for p in "${parts[@]}"; do
      local n
      n=$(to_num_day "$p") || { echo "bad day: $p" >&2; exit 2; }
      out+=("$n")
    done
  fi

  # unique + sorted
  printf "%s\n" "${out[@]}" | sort -n | uniq | tr '\n' ' '
}

hhmm() {
  # normalize HH:MM -> HHMM (zero-padded) without relying on locale
  local t="$1"
  if [[ "$t" =~ ^([0-2]?[0-9]):([0-5][0-9])$ ]]; then
    printf "%02d%02d" $((10#${BASH_REMATCH[1]})) $((10#${BASH_REMATCH[2]}))
  else
    echo "Invalid time: $t (expected HH:MM)" >&2
    exit 2
  fi
}

in_set() { # $1=needle $2...=haystack
  local x="$1"; shift
  for d in "$@"; do [[ "$d" == "$x" ]] && return 0; done
  return 1
}

# ---- evaluate window ----
read -r -a DAYS_ARR <<< "$(expand_days "$DAYS_SPEC")"

NOW_DAY=$(date +%u)  # 1..7 (Mon..Sun)
NOW_HM=$(date +%H%M)

START_HM=$(hhmm "$START")
END_HM=$(hhmm "$END")
NOW_HM=$(date +%H%M)

# force base-10 (kills the leading-zero/octal issue)
START_I=$((10#$START_HM))
END_I=$((10#$END_HM))
NOW_I=$((10#$NOW_HM))

# day check
if ! in_set "$NOW_DAY" "${DAYS_ARR[@]}"; then
  exit 0
fi

# time check (supports crossing midnight)
should_run=0
if (( END_I > START_I )); then
  # normal window
  if (( NOW_I >= START_I && NOW_I < END_I )); then should_run=1; fi
else
  # crosses midnight, e.g., 22:00..02:00
  if (( NOW_I >= START_I || NOW_I < END_I )); then should_run=1; fi
fi

# ---- run ----
if (( should_run == 1 )); then
  nohup bash -lc "${CMD[*]}" >/dev/null 2>&1 &
fi