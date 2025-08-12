# Zero-width tags per monitor id (adjust if you ever add a 3rd display)
ws_wrap_for_mid() {
  case "$1" in
    0) printf '\u200B \u200C' ;; # ZWSP / ZWNJ
    1) printf '\u200D \u2060' ;; # ZWJ / WORD JOINER
    *) printf '\u200E \u200F' ;; # LRM / RLM
  esac
}

ws_name_for_mid() { 
    read -r pfx sfx < <(ws_wrap_for_mid "$1"); 
    printf '%b%s%b' "$pfx" "$2" "$sfx"; 
}

ws_is_for_mid() { 
    read -r pfx sfx < <(ws_wrap_for_mid "$1"); 
    [[ "$2" == $pfx* && "$2" == *$sfx ]]; 
}
ws_strip_invis() { 
    sed -E 's/[\xE2\x80\x8B\xE2\x80\x8C\xE2\x80\x8D\xE2\x81\xA0\xE2\x80\x8E\xE2\x80\x8F]//g'; 
}
