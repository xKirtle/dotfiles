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

You can remove the `cue` parameter if you don't want visual cues telling you to touch the FIDO authenticator. Additionally, you can replace `sufficient` with `required` to require both your YubiKey + sudo password.

You can usually get away with just modifying `/etc/pam.d/system-local-login` since every local login relies on it (TTY, display managers, screen lockers, etc...). For `sudo` operations, modify `/etc/pam.d/sudo`.

## 4. Verify it's working
Before logging out (and potentially bricking your access), try authenticating on a new shell. Use `sudo -k` to clear your access cache, and try authenticating again using `sudo -v`.

___


# Managing SSH connections for Git with YubiKeys

Make sure the PC/SC daemon is running:
```bash
systemctl status pcsdcd

# Run if disabled
sudo systemctl enable --now pcscd
```

For the next steps, please configure one key at a time. Alternatively, you can target a specific key on your `ykman` commands. Check your keys with `ykman list` and start any command with `ykman --device [serial] ...`.

### 1. Generate a key-pair inside each YubiKey
```bash
# Key slot 9a is the standard for SSH
ykman --device [serial] piv keys generate \
    --algorithm RSA2048 \
    --pin-policy once \
    --touch-policy never \
    9a pubkey-[serial]-rsa.pem

```

You can modify `--pin-policy` and `--touch-policy` to whatever you prefer.

Then, create a matching self-signed certificate (needed so the slot is considered valid):
```bash
ykman --device [serial] piv certificates generate \
      9a pubkey-[serial]-rsa.pem \
      --subject "CN=Azure DevOps Key [serial] (RSA)" # Or whatever you want to call it

```

### 2. Install the PKCS#11 provider
```bash
paru -S opensc
```

and expore the public keys for where you want to use them with:
```bash
ssh-keygen -D /usr/lib/opensc-pkcs11.so > yubikey-[serial].pub
```

It should output something like this:
```bash
ssh-rsa AAAAE2VjZHNh...
```

If using multiple keys, it's probably best to only have one key connected at a time to easily know which pubkey is for which YubiKey.

Now you should have one or more `*.pub` files. Upload those public keys to whatever service you want to use them on.

### 3. Actually using it
This guide is more focused towards Azure DevOps, but if when trying to do an ssh request and it asks for a password (and not the PIN configured in your key), follow these steps:

```bash
# Start/ensure an agent is running
eval "$(ssh-agent -s)"

# (Re)add your token keys from the PKCS#11 module
ssh-add -e /usr/lib/opensc-pkcs11.so 2>/dev/null || true
ssh-add -s /usr/lib/opensc-pkcs11.so

# Confirm the agent sees them and verify fingerprints match
ssh-add -l

# Try Azure DevOps
ssh -T git@ssh.dev.azure.com
```

Azure DevOps does not offer you a shell back, so you should see something like `remote: Shell access is not supported`.

To simplify things, add this function to your fish shell so that you can load your ssh keys on demand at `~/.config/fish/functions/yk-ssh.fish`. Fish will automatically load it for you for each shell you open.
```fish
function yk-ssh
    # Start an ssh-agent if we don’t already have one
    if not ssh-add -l ^/dev/null
        eval (ssh-agent -c)
    end

    # If no YubiKey PIV keys are loaded, add the PKCS#11 module (will prompt for your PIV PIN once)
    if not ssh-add -l ^/dev/null | grep -q 'PIV AUTH pubkey'
        ssh-add -s /usr/lib/opensc-pkcs11.so
    end
end
```

Or if using bash (or derivatives):
```bash
yk_ensure_ssh() {
  # Start an ssh-agent if we don’t already have one
  if ! ssh-add -l >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null
  fi

  # If no YubiKey PIV keys are loaded, add the PKCS#11 module (will prompt for your PIV PIN once)
  if ! ssh-add -l 2>/dev/null | grep -q 'PIV AUTH pubkey'; then
    ssh-add -s /usr/lib/opensc-pkcs11.so
  fi
}
# optional convenience alias: run once before git/ssh
alias yk-ssh='yk_ensure_ssh'
```