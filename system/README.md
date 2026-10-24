# System files (/etc)

Reference copies of root-owned files changed on this machine. They're **not** linked by
`install.sh`; install them by hand, after reading what they do in `docs/`.

| File | What | Notes |
|---|---|---|
| `etc/greetd/config.toml` | greetd → ReGreet in a minimal Hyprland | `docs/04-login-and-session.md` |
| `etc/greetd/hyprland.lua` | Hyprland config for the login screen | `docs/04-login-and-session.md` |
| `etc/greetd/regreet.toml`, `regreet.css` | ReGreet settings and Catppuccin styling | `docs/04-login-and-session.md` |
| `etc/pam.d/greetd` | PAM for greetd (keyring unlock at login) | `docs/04-login-and-session.md` |
| `etc/pacman.conf` | `[multilib]` enabled (Steam) | `docs/06-gaming-and-steam.md` |

Install one (keeps a backup of what's there):

```bash
sudo install -b -m 644 etc/greetd/regreet.toml /etc/greetd/regreet.toml
```

Also needed once, so `themectl` can theme Chromium:

```bash
sudo install -d -o "$USER" -g "$USER" /etc/chromium/policies/managed
```

Refresh these copies after changing the real files, e.g. `cp /etc/greetd/regreet.toml etc/greetd/`.
