# Load YubiKey PIV keys into ssh-agent for current shell session
function yk-ssh
    # Start an ssh-agent if we don’t already have one
    if not ssh-add -l ^/dev/null
        eval (ssh-agent -c)
    end

    # If no YubiKey PIV keys are loaded, add the PKCS#11 module
    if not ssh-add -l ^/dev/null | grep -q 'PIV AUTH pubkey'
        ssh-add -s /usr/lib/opensc-pkcs11.so
    end
end