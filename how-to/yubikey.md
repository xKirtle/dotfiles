# YubiKey + Git & GPG on Arch Linux

## 1. YubiKey for PAM (login / sudo)

### 1.1 Install packages

```bash
paru -S pam-u2f yubikey-manager
```

### 1.2 Enroll your YubiKeys

```bash
mkdir -p ~/.config/Yubico
pamu2fcfg  > ~/.config/Yubico/u2f_keys     # Touch YubiKey when it blinks
pamu2fcfg >> ~/.config/Yubico/u2f_keys     # Run again to append a 2nd key
```

### 1.3 Enable PAM support (Pluggable Authentication Modules)

```bash
auth sufficient pam_u2f.so cue
```
- `cue` shows a visual prompt - remove if you prefer silent.
- Use `required` instead of `sufficient` to require both YubiKey **and** password.

Typical targets:
- `/etc/pam.d/system-local-login` - covers TTY, display managers, screen lockers.
- `/etc/pam.d/sudo` - protects `sudo`.

### 1.4 Test before logging out

```bash
sudo -k      # clear sudo cache
sudo -v      # should now require a YubiKey touch (if sudo target was changed)
```

## 2. Using YubiKeys for SSH (Git)

### 2.1 Make sure PC/SC is running

```bash
systemctl status pcscd
sudo systemctl enable --now pcscd   # if not active
```

### 2.2 Generate an on-device keypair

Work with one key at a time or target by serial from `ykman list`. Remove `--device <serial>` from the following snippets if only working with one yubikey at a time.

```bash
ykman --device <serial> piv keys generate \
    --algorithm RSA2048 \
    --pin-policy once \
    --touch-policy never \
    9a pubkey-<serial>.pem
```

Adjust `--pin-policy`/`--touch-policy` (`never | once | always`) to taste.

Create a self-signed certificate (slot 9a is standard for SSH):
```bash
ykman --device <serial> piv certificates generate \
      9a pubkey-<serial>.pem \
      --subject "CN=Azure DevOps Key <serial> (RSA)"
```

### 2.3 Install PKCS#11 provider & export the public key

```bash
paru -S opensc
ssh-keygen -D /usr/lib/opensc-pkcs11.so > yubikey-<serial>.pub
```

Upload the resulting ```ssh-rsa ...` key to GitHub/Azure DevOps.

### 2.4 using the key

```bash
eval "$(ssh-agent -s)"                     # start agent if needed
ssh-add -e /usr/lib/opensc-pkcs11.so 2>/dev/null || true
ssh-add -s /usr/lib/opensc-pkcs11.so       # add YubiKey key(s)
ssh-add -l                                 # confirm fingerprints
ssh -T git@ssh.dev.azure.com               # should print “Shell access is not supported.”
```
`eval` ensures ssh-agent is only available on the current shell.

### 2.5 Optional helper function

#### Fish (`~/.config/fish/functions/yk-ssh.fish`)
```fish
function yk-ssh
    if not ssh-add -l >/dev/null 2>&1
        eval (ssh-agent -c)
    end
    if not ssh-add -l >/dev/null 2>&1 | grep -q 'PIV AUTH pubkey'
        ssh-add -s /usr/lib/opensc-pkcs11.so
    end
end
```

## 3. Local SSH key without YubiKey

Install Seahorse (`paru -S seahorse`) and create a new **Secure Shell Key**. 
   The private key is stored in `~/.ssh/id_rsa`. Replace `id_rsa` with whatever name you picked (if any).

Add to `~/.ssh/config`:
```bash
Host github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes

Host ssh.dev.azure.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
```

## 4. GPG Commit Signing

### 4.1 Keys

Create two GPG keys in Seahorse:
- **Work (Azure DevOps)** - real name + company email.
- **Personal (GitHub)** - alias + personal email.

Copy the public key for each to:
- **GitHub**: Settings -> SSH and GPG keys -> New GPG key.
- **Azure DevOps**: no upload page - it verifies signatures directly from the commit.

### 4.2 Git helper functions

Add two Fish functions. One file each under `~/.config/fish/functions/` to benefit from Fish's autoloading (no need to source files).

Create two Fish functions under `~/.config/fish/functions/`. One named `git-personal.fish` and another `git-work.fish`. We create two separate files to benefit from Fish's autoloading of functions, so that we don't need to source those files ourselves. Both functions should look like this:

```fish
function git-personal --description "Configure current Git repo for personal commits"
    # Make sure we’re inside a Git repository
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Not a git repository."
        return 1
    end

    git config user.name  "Work/Personal Name"
    git config user.email "Work/Personal Email"
    git config user.signingkey Work/Personal GPG Key Id # No quotes
    git config commit.gpgSign true

    echo "Configured this repository to use the following identity:"
    git config --get user.name
    git config --get user.email
    git config --get user.signingkey
end
```

Run `git-personal` or `git-work` once inside each repository to set its identity.

### 4.3 Protect private data in your dotfiles repository

After adding real names/emails to those function files:

```bash
git update-index --assume-unchanged \
    .config/fish/functions/git-personal.fish \
    .config/fish/functions/git-work.fish
```

This keeps local edits out of future commits.