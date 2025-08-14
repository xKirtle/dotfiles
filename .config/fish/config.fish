# Only show banner on *interactive* sessions attached to a TTY
if status is-interactive; and test -t 1
    fastfetch
end
