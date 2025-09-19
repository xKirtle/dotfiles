function git-personal --description "Configure current Git repo for personal commits"
    # Make sure we’re inside a Git repository
    if not git rev-parse --is-inside-work-tree ^/dev/null
        echo "Not a git repository."
        return 1
    end

    git config user.name  "Your Personal Alias"
    git config user.email "you@personal.email"
    git config user.signingkey <PERSONAL_GPG_KEY_ID>
    git config commit.gpgSign true

    echo "Configured this repo for PERSONAL identity:"
    git config --get user.name
    git config --get user.email
    git config --get user.signingkey
end
