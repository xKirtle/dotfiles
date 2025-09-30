function git-personal --description "Configure current Git repo for personal commits"
    # Make sure we’re inside a Git repository
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Not a git repository."
        return 1
    end

    git config user.name  "xKirtle"
    git config user.email "rodm.martins@proton.me"
    git config user.signingkey 8ECF2A4CCAC44B13
    git config commit.gpgSign true

    echo "Configured this repository to use the following identity:"
    git config --get user.name
    git config --get user.email
    git config --get user.signingkey
end
