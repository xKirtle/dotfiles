# System monitor panel (task manager)

**Ctrl+Shift+Esc** (Windows' Task Manager shortcut) toggles a Quickshell panel with live graphs and a
process list you can filter, sort and end / force kill from. Ours, `sysmon` package.

```
Ctrl+Shift+Esc ─▶ sysmonctl panel ─▶ qs-panel sysmon sysmon ─▶ qs -c sysmon (panel)
                                                                   │ while open
                                       sysmonctl watch ◀───────────┘  one JSON line / s
                                       sysmonctl kill term|kill PID…  (Del / Shift+Del)
```

## Files (dotfiles `sysmon` package)

| Path | What |
|---|---|
| `~/.local/bin/sysmonctl` | `watch [SECONDS]` (streams samples, default 1 s), `kill term\|kill PID…` (JSON result), `panel` |
| `~/.config/quickshell/sysmon/shell.qml` | the panel |

## What it shows

- **Cards (last 60 s):** CPU (total %, fastest core's clock, Tctl temperature from `k10temp`, one bar per
  thread), Memory (used = total − available; cache, swap/zram), GPU (load + VRAM lines, temperature, power),
  Disk (read/write on whole disks, zram excluded; `/`, `/home`, `/boot` usage bars, refreshed every 10 s),
  Network (physical interfaces only, so the VPN tunnel isn't counted twice). Disk and Network graphs scale to
  their own peak ("scale" in the card).
- **Sources:** `/proc/stat`, `/proc/meminfo`, `/proc/diskstats`, `/proc/net/dev`, `/sys/class/hwmon`,
  `/proc/<pid>/{stat,statm,cmdline,io}`. GPU: one `nvidia-smi --query-gpu=… -lms=1000` kept running by
  `watch` (killed with it via `PR_SET_PDEATHSIG`).
- **Process columns:** CPU = % of the **whole machine** (24 threads; a process maxing one core shows ~4%),
  like Windows, not htop's per-core %. Memory = private (resident − shared pages), so shared libraries
  aren't counted once per process. Disk = read + write bytes/s, **own processes only** (other users'
  `/proc/<pid>/io` isn't readable; shows 0). Kernel threads are hidden. The name is the executable's
  name (`comm` is cut at 15 characters).
- Tints behind the numbers are a heat scale (full at 25% CPU / 4 GB / 50 MB/s).
- Only samples while open (~10 ms CPU per sample); the graphs start empty on each open.

## Keys

Type to filter (words match name, PID, user or command line). ↑/↓/PgUp/PgDn select, Enter or double-click =
expand / collapse a group (→/← too, when the cursor is at the end of the filter text / it's empty),
**Del = end task** (SIGTERM), **Shift+Del = force kill** (SIGKILL), or the buttons. Tab / Shift+Tab = next /
previous sort column (or click a header, again = reverse). Ctrl+G = group by name, Ctrl+P = pause the list
(the graphs keep going). Esc = cancel a confirmation, clear the filter, then close. The bottom bar shows the
selected row's command line.

## Killing

- **Groups** (on by default) merge processes with the same name (all `chromium` processes); ending a group
  signals every process in it (the ones matching the filter).
- **Asks first (Enter = yes)** for a force kill, anything hitting more than one process, and session
  pieces (`Hyprland`, `uwsm`, `systemd`, `dbus-broker`, `Xwayland`, `pipewire`, `wireplumber`, `qs`…; the
  `critical` list in `shell.qml`). A plain end task of one process goes straight through. The list
  freezes while the question is up.
- Processes of other users (root): `sysmonctl` retries them through `pkexec /usr/bin/kill` (polkit
  password prompt). PIDs 0–2 are refused.
- SIGTERM lets the app close itself (it may ask to save or ignore it); force kill if it's hung.

## Notes

- Doesn't live-reload reliably: after editing `shell.qml`, `qs -c sysmon kill`, the next Ctrl+Shift+Esc
  starts it again. Logs: `qs -c sysmon log`.
- Test the sampler without the panel: `sysmonctl watch | head -2 | jq 'del(.procs)'`.
