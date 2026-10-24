# Calendar: Proton Calendar reminders + agenda panel

Caelestia's calendar has no event support, so the `calendar` stow package adds it on the side:

```
Proton Calendar ICS link ──vdirsyncer (calendar-sync.timer, 15 min)──▶ ~/.local/share/calendars/proton/
                                                                          │ (khal reads it)
                          calendar-remind.service ◀── calendarctl ────────┤
                          (notify-send → Caelestia)                       │
                          Super+A agenda panel (qs -c agenda) ◀───────────┘
```

Read-only: Proton's share link is a one-way ICS feed. Add/edit events in Proton; local edits are
reverted on the next sync.

## Setup

1. Packages (official repos): `sudo pacman -S vdirsyncer khal`.
2. Link: Proton Calendar (web) → Settings → Calendars → the calendar → **Share** → "Share with anyone" →
   create a link (full view or busy-only) and copy it (menu names may have moved). **Anyone with the link can read the calendar**, so it
   only goes in the repo's gitignored `.env`, never in a tracked file:
   ```
   PROTON_CALENDAR_URL=https://calendar.proton.me/api/calendar/v1/url/…/calendar.ics?…
   ```
   (Quotes optional. Nothing to re-render: the configs read it at run time.)
3. First sync, then check:
   ```
   systemctl --user start calendar-sync.service
   journalctl --user -u calendar-sync -n 20
   khal list today 7d
   ```
4. Fresh machine: `./install.sh calendar` stows the package and enables `calendar-sync.timer` and
   `calendar-remind.service` (start them or log in again), then `hyprctl reload` for the bind.

How the link stays out of git: `~/.config/vdirsyncer/config` has `url.fetch = ["command",
"~/.local/bin/calendarctl", "url"]` (vdirsyncer's "fetch a value with a command"), and `calendarctl url`
prints `PROTON_CALENDAR_URL` from `.env`. It finds `.env` through its own symlink
(`<repo>/calendar/.local/bin/calendarctl` → `<repo>/.env`); `DOTFILES_ENV=<file>` overrides that.

## Files

| Path (all in `calendar/` in the repo) | What |
|---|---|
| `~/.config/vdirsyncer/config` | pair `proton`: `http` storage (the link) → `filesystem` vdir, `"a wins"`; status in `~/.local/share/vdirsyncer/status/` |
| `~/.config/khal/config` | calendar `proton` (read-only) on the vdir, Europe/Lisbon, ISO date/time formats (**calendarctl parses them; keep them**) |
| `~/.local/bin/calendarctl` | `sync`, `remind` (daemon), `remind --once [--dry-run]`, `agenda [--days N] [--offset D]` (JSON; D = first day relative to today, may be negative), `panel`, `url` |
| `~/.config/systemd/user/calendar-sync.{service,timer}` | sync 30 s after login, then every 15 min |
| `~/.config/systemd/user/calendar-remind.service` | reminder daemon (graphical session) |
| `~/.config/quickshell/agenda/shell.qml` | agenda panel |
| `~/.local/share/calendars/proton/` | synced events (one `.ics` per event); khal's cache: `~/.local/share/khal/` |
| `~/.local/state/calendar/sync.json` | last sync time / ok / error (shown in the panel) |
| `~/.local/state/calendar/notified.json` | reminders already sent (dedupe; entries pruned after 3 days) |

## Reminders

`calendarctl remind` (in `calendar-remind.service`) checks every minute, just after the minute turns.
It re-reads khal when the vdir changes, the date changes, or every 10 min, so recurring events are
expanded by khal (instances are keyed by event + start time).

- **Timed events:** a notification `CALENDAR_REMIND_MINUTES` (default **10**) before the start: title,
  time span, "in N min", location. One that's already less than 5 min old (late check, resume from
  suspend) still notifies; older ones are skipped.
- **All-day events:** one low-urgency "Today: …" notice on the event's **first day** at
  `CALENDAR_ALLDAY_TIME` (default **09:00**), or as soon as the session is up if that's later.
  Several on one day are grouped into one notice. Multi-day events don't repeat on later days.
- Each notice is sent **once** (`notified.json`), across restarts.
- Notifications: `notify-send -a Calendar -i x-office-calendar` → Caelestia's notification popup and sidebar.
- **Change the timings:** `systemctl --user edit calendar-remind` (adds a drop-in), e.g.
  ```
  [Service]
  Environment=CALENDAR_REMIND_MINUTES=15
  Environment=CALENDAR_ALLDAY_TIME=08:30
  ```
  then `systemctl --user restart calendar-remind`. (Or edit the unit in the repo to change the default.)
  Event alarms (VALARM) set in Proton are **not** used; it's one lead time for everything.

## Agenda panel

**Super+A** (`calendarctl panel` → `qs -c agenda ipc call agenda toggle`, starting `qs -c agenda -d` if
needed). Today + the next 4 days on the focused monitor, top-left beside the bar, styled like the
Claude usage panel (Caelestia scheme colours from `scheme.json`, Google Sans Flex). Per event: title,
time span or "all day" ("day 2/3" for multi-day), location, ⟳ for recurring. The running event is
highlighted, finished ones are dimmed; accent bar = primary (timed) / tertiary (all-day). Header
shows the last sync ("synced 11:23", "sync failed …", "not set up").
Keys: **↑/↓** (or k/j) select an event; **Enter**/**Space** or a click shows its **details**: full location,
the event's URL field and the description. The details are a read-only `TextEdit`: **click a link** to open it,
**drag to select** and **Ctrl+C** to copy (drag-scrolling pauses while the mouse is over the text; the wheel
still scrolls). Events with details show ▾. **O** opens the selected event's first link (URL field, then
location, then description); with no link it says so in the footer. Links open with `/usr/bin/xdg-open`
(default browser: `xdg-settings get default-web-browser`) and close the panel. The description is escaped
before links are added, so it can't inject markup.
Also: **←/→** (or h/l) page back/forward 5 days (the header then shows the date range), **T** (or Home)
jumps back to today, **R** syncs now, **Esc** or clicking elsewhere closes. Opening always starts at today. Refreshes on open, every minute while
open, and after each sync. After editing `shell.qml`: `qs -c agenda kill` (no live reload).

## Logs and checks

```
journalctl --user -u calendar-sync -u calendar-remind -n 50
systemctl --user list-timers calendar-sync.timer
cat ~/.local/state/calendar/sync.json
calendarctl agenda | python -m json.tool      # what the panel gets
calendarctl remind --once --dry-run           # what would notify right now (sends nothing)
qs -c agenda log                              # panel QML errors
```

## Troubleshooting

- **Panel says "not set up" / sync log says `PROTON_CALENDAR_URL not set`:** fill it in `.env`, then
  `systemctl --user start calendar-sync.service` (or R in the panel).
- **"khal/vdirsyncer is not installed":** `sudo pacman -S vdirsyncer khal`. The reminder daemon keeps
  retrying, so no restart is needed afterwards.
- **"Please run `vdirsyncer discover`":** `calendarctl sync` runs `discover proton` itself when vdirsyncer
  asks; by hand: `vdirsyncer discover proton && vdirsyncer sync proton`.
- **Sync fails with HTTP 4xx:** the link was revoked or mistyped; make a new one in Proton.
- **Times off by an hour:** khal's `local_timezone`/`default_timezone` must match `timedatectl`
  (Europe/Lisbon).
- **Start over** (e.g. after changing the link to another calendar):
  `rm -rf ~/.local/share/vdirsyncer/status ~/.local/share/calendars/proton/* ~/.local/share/khal`,
  then sync again.
- **Repeated or missing reminder:** check `notified.json` and `journalctl --user -u calendar-remind`
  ("notified: …" per notice).

## Testing without the real link

What was done when building this (2026-10-24): a sample `.ics` (timed event in a few minutes, all-day
today, two-day all-day, daily recurring with `TZID=Europe/Lisbon`) served by
`python3 -m http.server --bind 127.0.0.1` from a scratch dir, with copies of the vdirsyncer/khal
configs pointing at scratch paths, and `calendarctl` told to use them:
`DOTFILES_ENV=<test .env> VDIRSYNCER_CONFIG=… CALENDARCTL_KHAL_CONFIG=… CALENDARCTL_VDIR=… CALENDARCTL_STATE=…`
(khal's test config also needs its own `[sqlite] path`). Start `qs -c agenda -d` from that shell to
see the test data in the panel; `qs -c agenda kill` afterwards so the real one starts with the session env.
