# VPN: Proton VPN CLI + VPN panel

Proton VPN runs through Proton's official CLI (`proton-vpn-cli` from `extra`, binary `/usr/bin/protonvpn`,
signed in with `protonvpn signin`). On top of it: a picker panel (Super+Shift+P) and Caelestia's VPN
quick toggle.

```
Super+Shift+P ─▶ vpnctl panel ─▶ qs -c vpn (panel) ─▶ vpnctl list / status / connect / disconnect
                                                          │
Caelestia drawer VPN toggle ─▶ protonvpn connect|disconnect ◀┘  (state: is `proton0` up?)
```

## Files (dotfiles `vpn` package)

| Path | What |
|---|---|
| `~/.local/bin/vpnctl` | `status` (JSON, from NetworkManager + server cache, ~30 ms; `urllib.request` is imported only by `ip`, it cost `status` ~15 ms), `ip` (JSON: public IP, country, city, ISP as websites see you, from Mullvad's `am.i.mullvad.net/json`; works on or off the VPN. Proton's own `api.protonvpn.ch/vpn/location` refuses while connected, and the cache's `ExitIP` is the *entry* address), no request. The cache's `ExitIP` and the WireGuard endpoint are the *entry* address, not what websites see. Not connected: Proton's `api.protonvpn.ch/vpn/location`, which returns error 86081 while connected), `list` (JSON: usable servers by country → city, favourites), `connect [ARGS]`, `disconnect`, `fav CODE`, `panel` |
| `~/.config/quickshell/vpn/shell.qml` | the panel |
| `~/.cache/Proton/VPN/serverlist.json` | the CLI's server cache (all ~18k servers: name, city, load, score, features, tier); written by the CLI, read by vpnctl |
| `~/.cache/vpnctl/countries.json` | code → country name, from `protonvpn countries list` (re-read when the server cache changes) |
| `~/.cache/vpnctl/list.json` | `vpnctl list`'s countries JSON, first line = the server cache's mtime (ns); rebuilt when it changes (~200 ms → ~25 ms per panel open). Not written if country names failed |
| `~/.local/state/vpnctl/favorites.json` | favourite countries (default: PT) |

## How a connection looks

- `protonvpn connect` creates the interface **`proton0`**, a NetworkManager connection
  **`ProtonVPN <server>`** (e.g. `ProtonVPN PT#79`, type wireguard) and an IPv6 leak-protection dummy
  (`pvpn-killswitch-ipv6` / `ipv6leakintrf0`). `protonvpn disconnect` (~1 s) removes all three.
- `vpnctl status` finds the active `ProtonVPN …` connection and looks the server up in the cache.
- Server feature bits in the cache: 1 Secure Core, 2 Tor, 4 P2P, 8 streaming, 16 IPv6. Lower `Score` =
  faster (what "fastest" picks). `Tier` above the account's `MaxTier` and `Status: false` servers are
  hidden. Secure Core servers are named `SE-PT#1` (entry country first).
- CLI settings (`protonvpn config list` / `set`): NetShield malware-only, kill switch off, VPN accelerator
  on, moderate NAT off, port forwarding off, IPv6 on.

## Panel

**Super+Shift+P** (`vpnctl panel` → `qs-panel vpn vpn`: toggles it, or starts it at the shared panel scale; 03, Panel launcher).
Same look as the agenda panel (Caelestia scheme colours, Google Sans Flex, top left beside the bar).

- Top card: current server, city, country, load; your **public IP** (`IP: …`) with its **ISP** on the line below (MEO = not protected, Proton AG = on the VPN; looked up
  on open and 1.5 s after any connect/disconnect, including the drawer toggle; click copies it); **Quick connect** (fastest server, in the current mode)
  or **Disconnect**.
- Mode chips (Tab cycles): **Standard**, **Secure Core**, **P2P**. They filter the list, and connects add
  `-sc` / `--p2p`.
- Search box (focused on open): country name or code, city, or a server name with `#` (`PT#7`).
- List: favourites, then all countries (flag, server and city count, load of the fastest server). Click or
  Enter connects to the fastest server there; the chevron or →/← shows cities, then servers (fastest 25
  per city; search `XX#` for the rest). The star or Ctrl+F toggles a favourite. Ctrl+D disconnects. Esc
  clears the search, then closes.
- A dot marks the connected country, city and server. Status is polled every 2 s while open.

After editing `shell.qml`: `qs -c vpn kill` (no live reload); `qs -c vpn log` shows QML errors.

## Caelestia quick toggle

`utilities.vpn` in `shell.json.template`: one provider `proton`, interface `proton0`, connect/disconnect
`/usr/bin/protonvpn connect|disconnect` (fastest server). See `03-desktop-shell-and-theming.md`.

## Old WireGuard config

Before the CLI, a downloaded config was imported into NetworkManager as `wg-PT-66` (autoconnect off,
unused now). `nmcli connection import` **activates the tunnel immediately**: warn first, then import, set
`connection.autoconnect no`, and `nmcli connection down` it. Remove with `nmcli connection delete wg-PT-66`.

## Agents: don't switch the VPN yourself

Connecting, disconnecting or switching servers re-routes all traffic, which kills Claude Code's own API
connection mid-reply (the session hangs until the user sends another message). Ask the user to click or
run the command, then inspect the result. Warn them too: their own open connections drop on each switch.
