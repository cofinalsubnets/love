#!/bin/sh
# test/kore/pager.sh -- less and more -- one pager, both names, and the face on a pty
. "$(dirname "$0")/common.sh"

# `less` and `more` are ONE door (src/apps/kore/less.l). Its engine is lawed in laws.sh
# -- pgstep driven byte by byte, no tty in it -- and its face rides a
# real pty below. What belongs here is the lane a script actually takes: stdout is
# not a terminal, so the pager pours, and the pour has to be cat to the byte.
pg=$ho/.kore-pg
printf 'one\ntwo\nthree\n' > "$pg"
cat "$pg" > "$g"
for tool in less more; do
  korerun $tool "$pg" > "$o" 2>/dev/null || fail "kore $tool pouring a file"
  cmp -s "$g" "$o" || fail "kore $tool does not pour like cat"
done
korerun less < "$pg" > "$o" 2>/dev/null || fail "kore less pouring stdin"
cmp -s "$g" "$o" || fail "kore less does not pour stdin like cat"
# the flags are still read on that lane; an unknown one is usage's 2 and a name
# that will not open is 1
korerun less -Nse "$pg" > "$o" 2>/dev/null
cmp -s "$g" "$o" || fail "kore less -Nse does not pour like cat"
korerun less -z "$pg" > /dev/null 2>&1
[ $? -eq 2 ] || fail "kore less -z: not usage's 2"
korerun less "$pg.nope" > /dev/null 2>&1
[ $? -eq 1 ] || fail "kore less on a missing file: not 1"
echo "kore: less/more (one pager, both names; the pour lane byte-identical to cat) ok"
# ..and the FACE, which needs a terminal: test/host/less.l tethers one and types at it
echo "PAGER test/host/less.l (the face on a pty)"
cat test/00-init.l test/host/less.l | LOVEBIN=$K LESSTESTDIR=$HO "$m" > "$o" 2>&1
r=$?
{ [ $r -eq 0 ] && grep -q "test/host/less:" "$o"; } || { cat "$o"; fail "kore less on a pty (exit $r)"; }
tail -1 "$o"
