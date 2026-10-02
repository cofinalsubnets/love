#!/bin/sh
# test/gate/nest.sh -- `love nest`, the binary laying itself as the user's love, in a
# HOME of its own: the plan said (-n) and done (-y), the same build again, an older love,
# a newer one, one of the same stamp with other bytes, and -f. off a terminal a bare
# `love nest` is -y's; the floor (src/apps/lore/roost.l) is test/host/roost.l's. the installed love is a script where the
# case wants a stamp no build here carries; it answers `verbs` and `nest --stamp`.
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
fake() { printf '#!/bin/sh\n[ "$1" = verbs ] && { echo nest; exit 0; }\necho %s\n' "$1" > "$H/.love/bin/love"
         chmod 755 "$H/.love/bin/love"; }

mine=$("$love" nest --stamp)
[ "$mine" -gt 0 ] 2>/dev/null || fail "--stamp answers no stamp: '$mine'"

fresh
out=$(nest -n); st=$?
[ $st = 0 ] || fail "-n exits $st"
case $out in *"the nest has no love yet"*"lush     absent -> love"*) ;; *) fail "-n said: $out";; esac
[ -e "$H/.love/bin/love" ] && fail "-n laid a love"
out=$(nest -y); st=$?
[ $st = 0 ] || fail "a fresh nest exits $st: $out"
cmp -s "$love" "$H/.love/bin/love" || fail "a fresh nest did not lay this binary"
[ "$(readlink "$H/.love/bin/lush")" = love ] || fail "lush is not linked to love"
for t in kore sb cook libra mooncc lux; do
  [ -e "$H/.love/bin/$t" ] || [ -L "$H/.love/bin/$t" ] && fail "the one install laid $t"
done
[ "$(readlink "$H/.local/bin/lush")" = "$H/.love/bin/lush" ] || fail "no ~/.local/bin compat link"
[ "$("$H/.love/bin/lush" -c 'echo ok')" = ok ] || fail "the linked lush does not run"
[ "$("$H/.love/bin/lush" -ac 'kore echo ok')" = ok ] || fail "lush -ac does not run a verb"

# what earlier installs laid goes: tool links, the lux script, bao, the papel link, and
# their ~/.local/bin links -- a file the nest did not lay stays, and so does its link
b=$H/.love/bin l=$H/.local/bin
for t in kore mooncc ai; do ln -sf love "$b/$t"; ln -sf "$b/$t" "$l/$t"; done
{ echo '#!/usr/bin/env -S love -l'; cat src/apps/lux/core.l; } > "$b/lux"; ln -sf "$b/lux" "$l/lux"
printf '#!/bin/sh\nexec "$h/love" -e "((cite '"'"'cli '"'"'shell) 0)" "$@"\n' > "$b/bao"
ln -sf "$PWD/src/apps/papel.l" "$b/papel"
echo 'mine' > "$b/seed"; ln -sf "$b/seed" "$l/seed"
ln -sf "$b/gone" "$l/gone"
out=$(nest -n)
case $out in *"kore     laid by an earlier install, removed"*) ;; *) fail "-n did not plan the pruning: $out";; esac
out=$(nest); st=$?
[ $st = 0 ] || fail "the pruning nest exits $st: $out"
for t in kore mooncc ai lux bao papel; do
  [ -e "$b/$t" ] || [ -L "$b/$t" ] && fail "$t was not pruned"
done
for t in kore mooncc ai lux gone; do [ -L "$l/$t" ] && fail "~/.local/bin/$t was not pruned"; done
[ "$(cat "$b/seed")" = mine ] || fail "a file the nest did not lay was touched"
[ "$(readlink "$l/seed")" = "$b/seed" ] || fail "a link to a file the nest did not lay was touched"

out=$(nest); st=$?
[ $st = 0 ] || fail "the same build again exits $st"
case $out in *"this build already"*) ;; *) fail "the same build again said: $out";; esac

printf '#!/bin/sh\nexit 1\n' > "$H/.love/bin/love"     # older than nest: no verbs to ask
out=$(nest); st=$?
[ $st = 0 ] || fail "over an older love exits $st: $out"
cmp -s "$love" "$H/.love/bin/love" || fail "an older love was not replaced"

fake 4000000000
out=$(nest); st=$?
[ $st = 1 ] || fail "over a newer love exits $st, wanted 1"
case $out in *"-f lays this one"*) ;; *) fail "over a newer love said: $out";; esac

fake "$mine"
out=$(nest); st=$?
[ $st = 1 ] || fail "over the same stamp, other bytes, exits $st, wanted 1"
out=$(nest -f); st=$?
[ $st = 0 ] || fail "-f exits $st"
cmp -s "$love" "$H/.love/bin/love" || fail "-f did not replace"

out=$(nest -z); st=$?
[ $st = 2 ] || fail "an unknown option exits $st, wanted 2"

rm -rf "$H"
[ $fails = 0 ] || { echo "FAIL nest ($fails)"; exit 1; }
echo "nest: the binary lays itself newer-only, links lush, prunes what earlier installs laid, and -f overrides"
