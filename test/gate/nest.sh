#!/bin/sh
# test/gate/nest.sh -- `love nest`, the binary laying itself as the user's love, in a
# HOME of its own: a fresh nest, the same build again, another love replaced, what earlier
# installs laid pruned, and the build's name, a short hash of the source it carries, in
# --version and in nest's line.
#
# usage: sh test/gate/nest.sh LOVE
set -u
love=${1:-out/love}
case $love in /*) ;; *) love=$PWD/$love;; esac
H=$PWD/out/.nest
fails=0
fail() { echo "FAIL nest: $*"; fails=$((fails+1)); }
fresh() { rm -rf "$H"; mkdir -p "$H/.local/bin"; }
nest() { HOME=$H "$love" nest "$@" 2>&1; }

# the name: love, the version, and 8 hex of the carried source; the same on every ask
ver=$("$love" --version)
case $ver in "love $(cat VERSION) "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) fail "--version said: $ver";; esac
[ "$("$love" --version)" = "$ver" ] || fail "--version moved between two asks"
cp "$love" "$PWD/out/.nest-twin"
[ "$("$PWD/out/.nest-twin" --version)" = "$ver" ] || fail "a copy of these bytes has another name"
rm -f "$PWD/out/.nest-twin"

fresh
out=$(nest); st=$?
[ $st = 0 ] || fail "a fresh nest exits $st: $out"
[ "$out" = "love nest: installed ~/.love/bin/love ($ver)" ] || fail "a fresh nest said: $out"
cmp -s "$love" "$H/.love/bin/love" || fail "a fresh nest did not lay this binary"
[ "$(readlink "$H/.love/bin/lush")" = love ] || fail "lush is not linked to love"
for t in kore sb cook libra mooncc lux; do
  [ -e "$H/.love/bin/$t" ] || [ -L "$H/.love/bin/$t" ] && fail "the one install laid $t"
done
[ "$(readlink "$H/.local/bin/lush")" = "$H/.love/bin/lush" ] || fail "no ~/.local/bin compat link"
[ "$("$H/.love/bin/lush" -c 'echo ok')" = ok ] || fail "the linked lush does not run"
[ "$("$H/.love/bin/lush" -ac 'basename /x/ok')" = ok ] || fail "lush -ac does not run a verb"

# what earlier installs laid goes: tool links, the lux script, bao, the papel link, and
# their ~/.local/bin links -- a file the nest did not lay stays, and so does its link
b=$H/.love/bin l=$H/.local/bin
for t in kore mooncc ai; do ln -sf love "$b/$t"; ln -sf "$b/$t" "$l/$t"; done
{ echo '#!/usr/bin/env -S love -l'; cat src/apps/lux/core.l; } > "$b/lux"; ln -sf "$b/lux" "$l/lux"
printf '#!/bin/sh\nexec "$h/love" -e "((cite '"'"'cli '"'"'shell) 0)" "$@"\n' > "$b/bao"
ln -sf "$PWD/src/apps/papel.l" "$b/papel"
echo 'mine' > "$b/seed"; ln -sf "$b/seed" "$l/seed"
ln -sf "$b/gone" "$l/gone"
out=$(nest); st=$?
[ $st = 0 ] || fail "the pruning nest exits $st: $out"
[ "$out" = "love nest: ~/.love/bin/love is already this build ($ver)" ] || fail "the same build again said: $out"
for t in kore mooncc ai lux bao papel; do
  [ -e "$b/$t" ] || [ -L "$b/$t" ] && fail "$t was not pruned"
done
for t in kore mooncc ai lux gone; do [ -L "$l/$t" ] && fail "~/.local/bin/$t was not pruned"; done
[ "$(cat "$b/seed")" = mine ] || fail "a file the nest did not lay was touched"
[ "$(readlink "$l/seed")" = "$b/seed" ] || fail "a link to a file the nest did not lay was touched"

# any other love is replaced, older or not; lush is linked again if it went
printf '#!/bin/sh\necho 4000000000\n' > "$b/love"; rm -f "$b/lush"
out=$(nest); st=$?
[ $st = 0 ] || fail "over another love exits $st: $out"
[ "$out" = "love nest: installed ~/.love/bin/love ($ver)" ] || fail "over another love said: $out"
cmp -s "$love" "$b/love" || fail "another love was not replaced"
[ "$(readlink "$b/lush")" = love ] || fail "lush was not linked again"

# no flags: a word is refused, and the old ones with it
for o in -z -y -f -n --stamp; do
  out=$(nest $o); st=$?
  [ $st = 2 ] || fail "nest $o exits $st, wanted 2"
done
out=$(nest -h); st=$?
[ $st = 0 ] || fail "nest -h exits $st"
case $out in "usage: love nest"*) ;; *) fail "nest -h said: $out";; esac

rm -rf "$H"
[ $fails = 0 ] || { echo "FAIL nest ($fails)"; exit 1; }
echo "nest: the binary lays itself as $ver, links lush, prunes what earlier installs laid"
