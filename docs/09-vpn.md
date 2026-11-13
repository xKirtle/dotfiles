# VPN: Proton VPN CLI

Proton VPN runs through Proton's official CLI (`proton-vpn-cli` from `extra`, binary `/usr/bin/protonvpn`,
signed in with `protonvpn signin`), used from the command line (`protonvpn connect [--p2p|-sc]`,
`protonvpn disconnect`). A picker panel (`vpnctl`, `qs -c vpn`, Super+Shift+P) and a Caelestia drawer
toggle (`utilities.vpn`) existed until 2026-11-13; removed ahead of the subscription ending (git history has them).

## How a connection looks

- `protonvpn connect` creates the interface **`proton0`**, a NetworkManager connection
  **`ProtonVPN <server>`** (e.g. `ProtonVPN PT#79`, type wireguard) and an IPv6 leak-protection dummy
  (`pvpn-killswitch-ipv6` / `ipv6leakintrf0`). `protonvpn disconnect` (~1 s) removes all three.
- Server feature bits in the CLI cache (`~/.cache/Proton/VPN/serverlist.json`): 1 Secure Core, 2 Tor, 4 P2P, 8 streaming, 16 IPv6. Lower `Score` =
  faster (what "fastest" picks). `Tier` above the account's `MaxTier` and `Status: false` servers are
  hidden. Secure Core servers are named `SE-PT#1` (entry country first).
- CLI settings (`protonvpn config list` / `set`): NetShield malware-only, kill switch off, VPN accelerator
  on, moderate NAT off, port forwarding off, IPv6 on.

## Torrenting (qBittorrent)

Occasional torrents only (the home server does the heavy lifting). qBittorrent (`qbittorrent` package,
Qt, themed by the qt6ct palette, `03`); its config `~/.config/qBittorrent/` is not in the dotfiles.

- **Bound to the VPN:** Options → Advanced → Network interface **`proton0`** (`Session\Interface` in
  `qBittorrent.conf`), IP "All addresses". Off the VPN `proton0` doesn't exist, so torrents stall instead
  of leaking the real IP; this is why the CLI kill switch can stay off. If a torrent stays stuck after a
  reconnect, restart qBittorrent.
- **P2P servers only:** Proton allows torrents on P2P servers (feature bit 4 in the cache). Use
  `protonvpn connect --p2p`; plain "fastest" may pick a non-P2P server.
- **No port forwarding, on purpose:** Proton assigns a new random port on every connection (even to the
  same server), which qBittorrent would need each time. Without it, downloads work; you lose incoming peers
  (rare torrents can be slow) and seed poorly, which doesn't matter here. If that changes: `protonvpn config
  set port-forwarding on`, reconnect, and automate pushing the port into qBittorrent (Web API on localhost,
  a small user service) rather than typing it.

## Old WireGuard config

Before the CLI, a downloaded config was imported into NetworkManager as `wg-PT-66` (autoconnect off,
unused now). `nmcli connection import` **activates the tunnel immediately**: warn first, then import, set
`connection.autoconnect no`, and `nmcli connection down` it. Remove with `nmcli connection delete wg-PT-66`.

## Agents: don't switch the VPN yourself

Connecting, disconnecting or switching servers re-routes all traffic, which kills Claude Code's own API
connection mid-reply (the session hangs until the user sends another message). Ask the user to click or
run the command, then inspect the result. Warn them too: their own open connections drop on each switch.
