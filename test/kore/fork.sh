#!/bin/sh
# test/kore/fork.sh -- the shell's fork lane: self-PATH pipelines, status, cmdsub, nesting
. "$(dirname "$0")/common.sh"

# a word whose PATH winner is this binary forks instead of exec'ing. not observable from
# here, so these assert the plumbing with the winner self-symlinked: pipes, redirects,
# status, cmdsub, nesting, the symlink word
fb=$HO/.forkbin
mkdir -p "$fb"; ln -sf "$K" "$fb/love"; ln -sf "$K" "$fb/wc"; ln -sf "$K" "$fb/sort"
fsh() { PATH=$fb:$PATH LOVE_NO_IMAGE= "$m" sh -c "$1"; }
[ "$(fsh 'love echo hi | love wc -l')" = "1" ] || fail "fork lane pipeline"
[ "$(fsh 'love seq 5 | wc -l')" = "5" ] || fail "fork lane symlink word"
fsh 'love false'; r=$?; [ $r -eq 1 ] || fail "fork lane status (rc $r)"
# a lone foreground command forks too: status, redirects both ways, and a heredoc fed after the fork
printf 'b\na\nc\n' > "$HO/.fork-in"
[ "$(fsh 'love sort '"$HO"'/.fork-in | love tr -d "\n"')" = "abc" ] || fail "fork lane simple"
[ "$(fsh 'sort < '"$HO"'/.fork-in | love tr -d "\n"')" = "abc" ] || fail "fork lane simple stdin"
fsh 'sort '"$HO"'/.fork-in > '"$HO"'/.fork-o'
[ "$(tr -d '\n' < "$HO/.fork-o")" = "abc" ] || fail "fork lane simple stdout"
[ "$(fsh 'love cat <<EOF
deep
EOF')" = "deep" ] || fail "fork lane simple heredoc"
fsh 'love grep -q zzz '"$HO"'/.fork-in'; r=$?; [ $r -eq 1 ] || fail "fork lane simple status (rc $r)"
fsh 'love sh -c "love echo deep"' | grep -qx deep || fail "fork lane nested sh"
[ "$(fsh 'echo n=$(love echo abc | love wc -c)')" = "n=4" ] || fail "fork lane cmdsub"
fsh 'love seq 3 > '"$HO"'/.fork-r' ; [ "$(wc -l < "$HO/.fork-r")" = "3" ] || fail "fork lane redirect"
# the lane's reach is the binary: the child hands its line to cli-line, so `love -e` and
# `love VERB` ride it, with their statuses
[ "$(fsh 'echo x | love -e "(3 + 4)"')" = "7" ] || fail "fork lane love -e"
[ "$(fsh 'echo x | love echo nested')" = "nested" ] || fail "fork lane love VERB"
fsh 'echo x | love -e "(quit 9)"'; r=$?; [ $r -eq 9 ] || fail "fork lane love status (rc $r)"
# a rail that finishes is a 0: cli-line's answer is not a status
fsh 'echo x | love -e "(3 + 4)"' >/dev/null; r=$?; [ $r -eq 0 ] || fail "fork lane love -e rc (rc $r)"
# a knob read at boot cannot be honoured by a fork, so it must spawn: a 1 means the fork
# swallowed it. the knob rides the command (an egg-booted love has no verb table)
[ "$(fsh 'echo x | LOVE_NO_IMAGE=1 love -e "(elem (quote love-image) (names ()))"')" = "0" ] \
  || fail "fork lane swallowed LOVE_NO_IMAGE"
# every other boot knob, down every lane that runs this heap (stage, simple, export, cmdsub):
# a 64 MB budget cannot hold 4M cells and the shell's own can
big='love -e "(tally (jot 4000000))"'
[ "$(fsh "echo x | $big" 2>/dev/null)" = "4000000" ] || fail "fork lane big list (control)"
[ "$(fsh "echo x | LOVE_BUDGET_MB=64 $big" 2>/dev/null)" != "4000000" ] || fail "fork lane swallowed LOVE_BUDGET_MB (stage)"
[ "$(fsh "LOVE_BUDGET_MB=64 $big" 2>/dev/null)" != "4000000" ] || fail "fork lane swallowed LOVE_BUDGET_MB (simple)"
[ "$(fsh "export LOVE_BUDGET_MB=64; $big" 2>/dev/null)" != "4000000" ] || fail "fork lane swallowed LOVE_BUDGET_MB (export)"
[ "$(fsh "echo \$(LOVE_BUDGET_MB=64 $big)" 2>/dev/null)" != "4000000" ] || fail "fork lane swallowed LOVE_BUDGET_MB (cmdsub)"
off='love -e "(nil? natjit)"'
[ "$(fsh "echo x | $off")" = "0" ] || fail "fork lane glaze (control)"
[ "$(fsh "echo x | LOVE_NO_GLAZE=1 $off")" = "1" ] || fail "fork lane swallowed LOVE_NO_GLAZE (stage)"
[ "$(fsh "LOVE_NO_GLAZE=1 $off")" = "1" ] || fail "fork lane swallowed LOVE_NO_GLAZE (simple)"
[ "$(fsh "export LOVE_NO_GLAZE=1; echo \$($off)")" = "1" ] || fail "fork lane swallowed LOVE_NO_GLAZE (export, cmdsub)"
# an empty knob is no knob: the glaze stays on
[ "$(fsh "LOVE_NO_GLAZE= $off")" = "0" ] || fail "fork lane empty LOVE_NO_GLAZE"
# a bare word may want a terminal: it spawns only when it would inherit one; a pipe or a `<` on fd 0 forks
[ "$(fsh 'echo "(puts \"bare\")" | love')" = "bare" ] || fail "fork lane bare word"
[ "$(fsh 'love seq 3 | sort | love tr -d "\n"')" = "123" ] || fail "fork lane bare stage"
echo "kore: the fork lane (self-PATH pipelines, status, cmdsub, nesting, love's own line) ok"
