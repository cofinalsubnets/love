#!/bin/sh
# test/kore/find.sh -- find: the walks compare SETS, the order being the file system's business
. "$(dirname "$0")/common.sh"

# THE ORDER IS SORTED ON BOTH SIDES. find hands out readdir order, which is the
# file system's business and repeats for nobody; ours sorts each directory on
# purpose (a build wants the same tree to cut the same image twice), so the only
# honest comparison is of the SETS. everything else here is byte-identical.
ft=$ho/.kore-ftree
rm -rf "$ft"; mkdir -p "$ft/a/b" "$ft/c"
: > "$ft/f1.txt"; : > "$ft/a/f2.txt"; : > "$ft/a/b/f3.log"; : > "$ft/c/f4.txt"
ln -sf f1.txt "$ft/link1"
fd() { n=$1; shift
       find "$@" 2>/dev/null | LC_ALL=C sort > "$g"
       korerun find "$@" 2>/dev/null | LC_ALL=C sort > "$o"
       same "find $n"; }
fd plain     "$ft"
fd name      "$ft" -name '*.txt'
fd nameq     "$ft" -name 'f?.txt'
fd typef     "$ft" -type f
fd typed     "$ft" -type d
fd typel     "$ft" -type l
fd not       "$ft" '!' -type d
fd and       "$ft" -type f -name '*.txt'
fd or        "$ft" -name '*.log' -o -name '*.txt'
fd parens    "$ft" '(' -name '*.log' -o -name link1 ')'
fd maxdepth0 "$ft" -maxdepth 0
fd maxdepth1 "$ft" -maxdepth 1
fd mindepth2 "$ft" -mindepth 2
fd path      "$ft" -path '*/apps/*'
fd prune     "$ft" -path '*/a' -prune -o -print
fd twopaths  "$ft/a" "$ft/c"
fd explicit  "$ft" -name '*.txt' -print
fd notname   "$ft" '!' -name '*.txt'
# -exec runs the command once per name; the output is ours to compare directly
korerun find "$ft" -name '*.log' -exec echo FOUND '{}' ';' > "$o" 2>/dev/null
[ "$(cat "$o")" = "FOUND $ft/a/b/f3.log" ] || fail "kore find -exec: $(cat "$o")"
# a path that is not there complains and the code remembers; the others still walk
korerun find "$ft/nope" "$ft/c" > "$o" 2>"$g"; r=$?
[ $r -eq 1 ] && [ -s "$g" ] && grep -q 'f4.txt' "$o" || fail "kore find missing path (exit $r)"
# a malformed expression is a refusal, not a walk
korerun find "$ft" -name > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore find bad expression (exit $r)"
echo "kore: find (18 walks set-identical to the system find, -exec, the two refusals) ok"
