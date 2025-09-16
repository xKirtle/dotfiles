# YubiKey + PAM Setup on Arch Linux

## 1. Install required packages

```bash
paru -S pam-u2f yubikey-manager
```

## 2. Enroll YubiKeys
Create a directory to store U2F mappings:

```bash
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys # Touch YubiKey when it blinks.

# if using multiple yubikeys, append to file
pamu2fcfg >> ~/.config/Yubico/u2f_keys
```

## 3. Enable YubiKey for specific services
PAM configuration lives in `/etc/pam.d/`
Each service has its own file.

You will always want to add something like the snippet below at the very top (1st auth rule), if you want to only rely on your YubiKey.

```bash
auth sufficient pam_u2f.so cue 
```

If you can remove the `cue` parameter if you don't want visual cues telling you to touch the FIDO authenticator. Additionally, you can replace `sufficient` with `required` to require both your YubiKey + sudo password.

You can usually get away with just modifying `/etc/pam.d/system-local-login` since every local login relies on it (TTY, display managers, screen lockers, etc...). For sudo operations, modify `/etc/pam.d/sudo`.

## 4. Verify it's working
Before logging out (and potentially bricking your access), try authenticating on a new shell. Use `sudo -k` to clear your access cache, and try authenticating again using `sudo -v`.