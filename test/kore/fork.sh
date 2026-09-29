#!/bin/sh
# test/kore/fork.sh -- the shell's fork lane: self-PATH pipelines, status, cmdsub, nesting
. "$(dirname "$0")/common.sh"

# an external word whose PATH winner IS this binary FORKS instead of exec'ing
# (src/apps/lush.l sh-forkfn): the child rides the warm heap and no stage pays
# a second wake. fork-vs-spawn is not portably observable from out here (landed
# against an execve trace: one exec for the shell, none for the stages) -- so
# these assert the lane's PLUMBING with the winner self-symlinked, the distro's
# shadow shape: pipes, redirects, status, cmdsub, nesting, the symlink word.
fb=$HO/.forkbin
mkdir -p "$fb"; ln -sf "$K" "$fb/kore"; ln -sf "$K" "$fb/wc"; ln -sf "$K" "$fb/sort"
fsh() { PATH=$fb:$PATH LOVE_NO_IMAGE= "$m" sh -c "$1"; }
[ "$(fsh 'kore echo hi | kore wc -l')" = "1" ] || fail "fork lane pipeline"
[ "$(fsh 'kore seq 5 | wc -l')" = "5" ] || fail "fork lane symlink word"
fsh 'kore false'; r=$?; [ $r -eq 1 ] || fail "fork lane status (rc $r)"
# the SIMPLE FOREGROUND command takes the lane too, not just a pipeline stage: a word
# that misses the in-image list is still ours to fork. these are the shapes a one-command
# line owes -- status, redirects both ways, and a heredoc, whose write end the parent
# feeds after the fork exactly as it does after a spawn.
printf 'b\na\nc\n' > "$HO/.fork-in"
[ "$(fsh 'kore sort '"$HO"'/.fork-in | kore tr -d "\n"')" = "abc" ] || fail "fork lane simple"
[ "$(fsh 'sort < '"$HO"'/.fork-in | kore tr -d "\n"')" = "abc" ] || fail "fork lane simple stdin"
fsh 'sort '"$HO"'/.fork-in > '"$HO"'/.fork-o'
[ "$(tr -d '\n' < "$HO/.fork-o")" = "abc" ] || fail "fork lane simple stdout"
[ "$(fsh 'kore cat <<EOF
deep
EOF')" = "deep" ] || fail "fork lane simple heredoc"
fsh 'kore grep -q zzz '"$HO"'/.fork-in'; r=$?; [ $r -eq 1 ] || fail "fork lane simple status (rc $r)"
fsh 'kore sh -c "kore echo deep"' | grep -qx deep || fail "fork lane nested sh"
[ "$(fsh 'echo n=$(kore echo abc | kore wc -c)')" = "n=4" ] || fail "fork lane cmdsub"
fsh 'kore seq 3 > '"$HO"'/.fork-r' ; [ "$(wc -l < "$HO/.fork-r")" = "3" ] || fail "fork lane redirect"
# ..and the lane's reach is the BINARY, never a verb list: the child hands its whole
# line to cli-line (src/love/boot/post.l), the very door an exec would have reached, so a word
# that dispatches through argv[1] rides it too -- `love -e`, `love VERB`, and the
# status either answers with.
ln -sf "$K" "$fb/love"
[ "$(fsh 'echo x | love -e "(3 + 4)"')" = "7" ] || fail "fork lane love -e"
[ "$(fsh 'echo x | love kore echo nested')" = "nested" ] || fail "fork lane love VERB"
fsh 'echo x | love -e "(quit 9)"'; r=$?; [ $r -eq 9 ] || fail "fork lane love status (rc $r)"
# ..and a rail that simply FINISHES is a 0. cli-line's answer is not a status -- every
# status it carries it quits with itself -- so a child that quit with the answer instead
# exited `-e` with the newline that printed it.
fsh 'echo x | love -e "(3 + 4)"' >/dev/null; r=$?; [ $r -eq 0 ] || fail "fork lane love -e rc (rc $r)"
# THE REFUSALS. A knob read at boot cannot be honoured by a fork -- the heap is
# already whichever one this process woke -- so the ask has to spawn, and this is the
# one refusal observable from out here: a 1 means the lane forked and swallowed it.
# (the knob rides the COMMAND, never the shell: an egg-booted love has no verb table,
# so `love sh` there would read "sh" as a filename.)
[ "$(fsh 'echo x | LOVE_NO_IMAGE=1 love -e "(elem (quote love-image) (names ()))"')" = "0" ] \
  || fail "fork lane swallowed LOVE_NO_IMAGE"
# a word with nothing past it may want a terminal, and the repl is the caller's isatty
# answer to give -- so the bare word is asked of the STAGE, not of the word: a pipe or a
# `<` laying fd 0 answers it, and only a bare word that would inherit a terminal spawns.
# that releases every `| cat`, `| sort`, `| tee` there is, and the stdin drink still lands.
[ "$(fsh 'echo "(puts \"bare\")" | love')" = "bare" ] || fail "fork lane bare word"
[ "$(fsh 'kore seq 3 | sort | kore tr -d "\n"')" = "123" ] || fail "fork lane bare stage"
echo "kore: the fork lane (self-PATH pipelines, status, cmdsub, nesting, love's own line) ok"
