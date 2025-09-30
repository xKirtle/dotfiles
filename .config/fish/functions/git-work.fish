function git-work --description "Configure current Git repo for work commits"
    # Make sure we’re inside a Git repository
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Not a git repository."
        return 1
    end

    git config user.name  "Rodrigo Martins"
    git config user.email "rodrigo.martins@unit4.com"
    git config user.signingkey 47787D3E30F2D9C9
    git config commit.gpgSign true

    echo "Configured this repository to use the following identity:"
    git config --get user.name
    git config --get user.email
    git config --get user.signingkey
end
