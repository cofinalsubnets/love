#!/bin/sh
# test/kore/door.sh -- --help and --version at the door
. "$(dirname "$0")/common.sh"

# apps/kore/kore.l's koredoor answers the two flags for every applet, on BOTH dispatch
# lanes -- `hv` is common.sh's, the archives use it too.
# the nested lane (`kore TOOL`) and the verb lane (`love TOOL`) must agree
hv "awk -h"          '^usage: awk'   korerun awk -h
hv "awk --help"      '^usage: awk'   korerun awk --help
hv "awk --version"   '^awk (love'    korerun awk --version
hv "love awk --help" '^usage: awk'   "$m" awk --help
hv "love awk -h"     '^usage: awk'   "$m" awk -h
hv "cat --help"      '^usage: cat'   korerun cat --help
hv "sed --version"   '^sed (love'    korerun sed --version
hv "bc --version"    '^bc (love'     korerun bc --version
hv "ls -l --help"    '^usage: ls'    korerun ls -l --help
hv "kore --help"     '^kore -- the'  "$m" kore --help
hv "kore --version"  '^kore (love'   "$m" kore --version
# ..and the letters that are NOT the door's: grep -h suppresses the filename (GNU says
# what it says), ls -h is ls's own human sizes, echo hands back the word it was given
printf 'a\nb\n' > "$ho/.hv1"; printf 'a\nX\n' > "$ho/.hv2"
both "grep -h is grep's own" grep -h a "$ho/.hv1" "$ho/.hv2"
korerun ls -h "$ho/.hv1" > "$o" 2>&1; r=$?
[ $r -eq 0 ] && ! grep -q '^usage' "$o" || fail "kore ls -h: ls's own flag, not the help (exit $r)"
printf -- '--help\n' > "$g"; korerun echo --help > "$o" 2>/dev/null
same "echo --help is the word"
echo "kore: --help / --version at the door ok"
