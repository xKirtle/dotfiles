# ws-lib.sh — shared helpers for Hyprland local-slot workflows (zero-width naming)

# ─── Zero-width tags per monitor id ────────────────────────────────────────────
ws_wrap_for_mid() {
  case "$1" in
    0) printf '\u200B \u200C' ;; # ZWSP / ZWNJ
    1) printf '\u200D \u2060' ;; # ZWJ / WORD JOINER
    *) printf '\u200E \u200F' ;; # LRM / RLM
  esac
}

ws_name_for_mid() {
  # $1=mid $2=slot
  read -r pfx sfx < <(ws_wrap_for_mid "$1")
  printf '%b%s%b' "$pfx" "$2" "$sfx"
}

ws_is_for_mid() {
  # $1=mid $2=name
  read -r pfx sfx < <(ws_wrap_for_mid "$1")
  [[ "$2" == $pfx* && "$2" == *$sfx ]]
}

ws_strip_invis() {
  # ZWSP \u200B, ZWNJ \u200C, ZWJ \u200D, WJ \u2060, LRM \u200E, RLM \u200F
  sed -E 's/[\xE2\x80\x8B\xE2\x80\x8C\xE2\x80\x8D\xE2\x81\xA0\xE2\x80\x8E\xE2\x80\x8F]//g'
}

# ─── Snapshots & context ──────────────────────────────────────────────────────
ws_focus() {
  # Sets MID, MNAME
  local mons
  mons="$(hyprctl -j monitors)" || return 1
  MID="$(jq -r '.[] | select(.focused==true).id' <<<"$mons")"
  MNAME="$(jq -r '.[] | select(.focused==true).name' <<<"$mons")"
  [[ "$MID" != "null" && -n "$MNAME" ]]
}

ws_wsjson() { WS_JSON="$(hyprctl -j workspaces || echo '[]')" ; }
ws_clients_json() { CL_JSON="$(hyprctl -j clients || echo '[]')" ; }

# ─── Local slot helpers ───────────────────────────────────────────────────────
ws_current_local_slot() {
  # prints current local slot number ('' if none)
  local cur
  cur="$(hyprctl -j activeworkspace | jq -r '.name // empty')" || return 0
  if [[ "$cur" =~ ^[0-9]+$ ]]; then
    jq -e --arg mon "$MNAME" --arg n "$cur" 'any(.[]; .monitor==$mon and .name==$n)' >/dev/null <<<"$WS_JSON" \
      && { printf '%s' "$cur"; return; }
  elif ws_is_for_mid "$MID" "$cur"; then
    printf '%s' "$cur" | ws_strip_invis; return
  fi
  printf ''
}

ws_list_existing_local_slots() {
  # newline-separated sorted numeric local slots (numeric on this monitor ∪ wrapped-for-this-MID anywhere)
  local slots_num slots_wrapped
  slots_num="$(jq -r --arg mon "$MNAME" '.[] | select(.monitor==$mon) | .name' <<<"$WS_JSON" | grep -E '^[0-9]+$' || true)"
  slots_wrapped="$(jq -r '.[].name' <<<"$WS_JSON" | while read -r n; do
    ws_is_for_mid "$MID" "$n" && printf '%s\n' "$n" | ws_strip_invis || true
  done)"
  printf "%s\n%s\n" "$slots_num" "$slots_wrapped" | grep -E '^[0-9]+$' | sort -n | uniq
}

ws_max_exist() {
  local max=0 line
  while IFS= read -r line; do max="$line"; done < <(ws_list_existing_local_slots)
  printf '%s' "$max"
}

ws_last_occupied() {
  # prints highest occupied local slot on this monitor (0 if none)
  jq -r --arg mon "$MNAME" --argjson ws "$WS_JSON" '
    def strip: gsub("\u200b|\u200c|\u200d|\u2060|\u200e|\u200f";"");
    [ .[] as $c
      | ($ws[] | select(.id == $c.workspace.id)) as $w
      | select($w.monitor == $mon)
      | ($w.name | strip)
      | select(test("^[0-9]+$"))
      | tonumber
    ] | max? // 0
  ' <<<"$CL_JSON"
}

ws_slot_exists() {
  # $1=slot ; returns 0 if exists locally, 1 otherwise
  local slot="$1"
  jq -e --arg mon "$MNAME" --arg n "$slot" 'any(.[]; .monitor==$mon and .name==$n)' >/dev/null <<<"$WS_JSON" && return 0
  local w; w="$(ws_name_for_mid "$MID" "$slot")"
  jq -e --arg w "$w" 'any(.[]; .name==$w)' >/dev/null <<<"$WS_JSON"
}

ws_target_name_for_slot() {
  # $1=slot → echoes name (prefer numeric-on-monitor else wrapped)
  local slot="$1" found
  found="$(jq -r --arg mon "$MNAME" --arg n "$slot" '.[] | select(.monitor==$mon and .name==$n) | .name' <<<"$WS_JSON")"
  if [[ -n "$found" ]]; then printf '%s' "$found"; else ws_name_for_mid "$MID" "$slot"; fi
}

ws_goto_slot() {
  # $1=slot → dispatch + pin to focused monitor
  local slot="$1" tgt
  tgt="$(ws_target_name_for_slot "$slot")"
  hyprctl dispatch workspace "name:${tgt}" >/dev/null
  hyprctl dispatch moveworkspacetomonitor "name:${tgt}" "$MNAME" >/dev/null 2>&1 || true
}

# ─── Decision logic (targets) ─────────────────────────────────────────────────
ws_active_ws_client_count() {
  # number of clients on the ACTIVE workspace (requires ws_clients_json called)
  local aw wsid
  aw="$(hyprctl -j activeworkspace)" || { printf '0'; return; }
  wsid="$(jq -r '.id' <<<"$aw")"
  jq -r --argjson id "$wsid" '[ .[] | select(.workspace.id==$id) ] | length' <<<"$CL_JSON"
}

ws_decide_target_goto() {
  # $1 = N (local index). Prints *target slot number* or '' for no-op.
  # Rules:
  #  • If Nth existing local slot exists → go to that slot.
  #  • If N > count → create/clamp to boundary:
  #      B = (LAST_OCC == 0 ? MAX_EXIST+1 : LAST_OCC+1)
  #  • Extra: if current workspace is EMPTY, block *upward* moves (no walking).

  local N="$1"

  local CUR;   CUR="$(ws_current_local_slot)"     # current slot number (e.g., 12)
  local MAX;   MAX="$(ws_max_exist)"              # max existing slot number   (e.g., 14)
  local LAST;  LAST="$(ws_last_occupied)"         # highest occupied slot num  (0 if none)

  # 1) If the Nth existing local slot is present → use it (pure index semantics)
  local EXIST_SLOT
  EXIST_SLOT="$(ws_nth_existing_local_slot "$N")"
  if [[ -n "$EXIST_SLOT" ]]; then
    # no-op if we’re already on it
    [[ "$CUR" == "$EXIST_SLOT" ]] && { printf ''; return; }
    printf '%s' "$EXIST_SLOT"
    return
  fi

  # 2) N beyond count → boundary creation/clamp (single step)
  local B
  if (( LAST == 0 )); then
    B=$((MAX + 1))         # first creation from a single existing slot
  else
    B=$((LAST + 1))        # occupied boundary
  fi

  # 3) If current is EMPTY, block *upward* moves (prevents indefinite stepping)
  if [[ -n "$CUR" ]]; then
    local c; c="$(ws_active_ws_client_count)"
    if (( c == 0 )) && (( B > CUR )); then
      printf ''            # block upward when current is empty
      return
    fi
  fi

  # no-op if already at the boundary
  [[ "$CUR" == "$B" ]] && { printf ''; return; }

  printf '%s' "$B"
}

# Decide target for MOVE (index semantics) with "empty-upward" guard
# $1=N(index) $2=mode(one|all) $3=src_ws_id
ws_decide_target_move() {
  local N="$1" MODE="$2" SRC_ID="$3"

  local CUR;  CUR="$(ws_current_local_slot)"   # slot number (e.g., 12)
  local MAX;  MAX="$(ws_max_exist)"
  local LAST; LAST="$(ws_last_occupied)"

  # If Nth existing local slot exists → go there
  local EXIST_SLOT; EXIST_SLOT="$(ws_nth_existing_local_slot "$N")"
  local TGT=''
  if [[ -n "$EXIST_SLOT" ]]; then
    TGT="$EXIST_SLOT"
  else
    # N beyond count → single-step boundary
    local B
    if (( LAST == 0 )); then
      B=$((MAX + 1))       # first creation on fresh screen
    else
      B=$((LAST + 1))      # occupied boundary
    fi
    TGT="$B"
  fi

  # No-op if target equals current
  [[ -n "$CUR" && "$CUR" -eq "$TGT" ]] && { printf ''; return; }

  # Empty-upward guard: if moving would empty source AND TGT > CUR → block
  local SRC_COUNT
  SRC_COUNT="$(jq -r --argjson id "$SRC_ID" '[ .[] | select(.workspace.id==$id) ] | length' <<<"$CL_JSON")"
  local EMPTIES=0
  if [[ "$MODE" == "all" ]]; then
    EMPTIES=1
  else
    (( SRC_COUNT == 1 )) && EMPTIES=1 || EMPTIES=0
  fi
  if (( EMPTIES == 1 )) && [[ -n "$CUR" ]] && (( TGT > CUR )); then
    printf ''; return
  fi

  printf '%s' "$TGT"
}

# Return the slot number of the Nth existing local slot on the focused monitor
# (numeric-on-this-monitor ∪ wrapped-for-this-MID), or '' if N > count.
ws_nth_existing_local_slot() {
  local N="$1"
  mapfile -t _SLOTS < <(ws_list_existing_local_slots)   # e.g., 12 13 14
  (( N >= 1 && N <= ${#_SLOTS[@]} )) || { printf ''; return; }
  printf '%s' "${_SLOTS[$((N-1))]}"
}
