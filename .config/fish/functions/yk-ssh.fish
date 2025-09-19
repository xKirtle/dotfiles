# Load YubiKey PIV keys into ssh-agent for current shell session
function yk-ssh --description "Start ssh-agent if needed and add YubiKey (PKCS#11) keys"
    # If SSH_AUTH_SOCK is set but not a socket, clear it (stale env)
    if test -n "$SSH_AUTH_SOCK"; and not test -S "$SSH_AUTH_SOCK"
        set -e SSH_AUTH_SOCK
    end

    # Ensure an agent is running and responsive
    if not ssh-add -l >/dev/null 2>&1
        eval (ssh-agent -c)

        # Wait up to ~2s for the socket to appear and the agent to respond
        for i in (seq 1 20)
            if test -S "$SSH_AUTH_SOCK"
                if ssh-add -l >/dev/null 2>&1
                    break
                end
            end
            sleep 0.1
        end
    end

    # If no YubiKey PIV keys are loaded, add the PKCS#11 module (will prompt for your PIN)
    if not ssh-add -l 2>/dev/null | grep -q 'PIV AUTH pubkey'
        ssh-add -s /usr/lib/opensc-pkcs11.so
    end
end
