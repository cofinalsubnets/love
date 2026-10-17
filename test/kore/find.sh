#!/bin/sh
# test/kore/find.sh -- find: the walks compare as sets
. "$(dirname "$0")/common.sh"

# both sides sorted: gnu walks readdir order, ours sorts on purpose. the rest is byte-identical
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
# -exec runs once per name
korerun find "$ft" -name '*.log' -exec echo FOUND '{}' ';' > "$o" 2>/dev/null
[ "$(cat "$o")" = "FOUND $ft/a/b/f3.log" ] || fail "kore find -exec: $(cat "$o")"
# a missing path complains and sets the code; the others still walk
korerun find "$ft/nope" "$ft/c" > "$o" 2>"$g"; r=$?
[ $r -eq 1 ] && [ -s "$g" ] && grep -q 'f4.txt' "$o" || fail "kore find missing path (exit $r)"
# a malformed expression is a refusal, not a walk
korerun find "$ft" -name > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore find bad expression (exit $r)"
# -iname -ipath -empty -newer -mtime -mmin -size -perm, -L, -depth; -print0 and -exec {} +
# as sorted words; -delete of a subtree, and of a non-empty directory
F=$ho/.findp; rm -rf "$F"; mkdir -p "$F/t/a/b" "$F/t/e"
printf 'x%.0s' $(seq 1 1500) > "$F/t/a/big"; : > "$F/t/a/zero"; echo hi > "$F/t/a/Hi.TXT"; echo s > "$F/t/a/b/s.c"
chmod 640 "$F/t/a/zero"; chmod 755 "$F/t/a/big"; touch -d '3 days ago' "$F/t/a/b/s.c"; touch -d '10 minutes ago' "$F/t/a/Hi.TXT"
touch -d '1 hour ago' "$F/ref"; ln -s a "$F/t/la"
for x in "-iname hi.*" "-ipath */A/*" "-empty" "-newer $F/ref" "-mtime +1" "-mtime -1" "-mmin -30" "-mmin +30" "-size +2" "-size -1" \
         "-size 1500c" "-size +1k" "-perm 640" "-perm -644" "-perm /111" "-perm -u=rw" "-depth" "-name s.c"; do
  # shellcheck disable=SC2086
  find "$F/t" $x | sort > "$g"; korerun find "$F/t" $x | sort > "$o"; same "find $x"
done
find -L "$F/t" -name s.c | sort > "$g"; korerun find -L "$F/t" -name s.c | sort > "$o"; same "find -L"
find "$F/t" -print0 | tr '\0' '\n' | sort > "$g"; korerun find "$F/t" -print0 | tr '\0' '\n' | sort > "$o"; same "find -print0"
# -printf line by line, sorted: %p %m %U %G %T@ and the rest
for f in '%p %m %U %G\n' '%T@ %p\n' '%f|%h|%y|%s\n' '%%\t%p\0'; do
  find "$F/t" -printf "$f" | tr '\0' '\n' | sort > "$g"; korerun find "$F/t" -printf "$f" | tr '\0' '\n' | sort > "$o"; same "find -printf '$f'"
done
find "$F/t" -type f -exec echo X {} + | tr ' ' '\n' | sort > "$g"; korerun find "$F/t" -type f -exec echo X {} + | tr ' ' '\n' | sort > "$o"; same "find -exec {} +"
korerun find "$F/t" -name b > /dev/null; korerun find "$F/t" -name b -delete 2> /dev/null; r=$?
[ $r -eq 1 ] && [ -d "$F/t/a/b" ] || fail "kore find -delete of a directory not empty (rc $r)"
korerun find "$F/t" ( -path '*/a/b' -o -path '*/a/b/*' ) -delete && [ ! -e "$F/t/a/b" ] && [ -f "$F/t/a/big" ] || fail "kore find -delete of a subtree"
rm -rf "$F"
echo "kore: find (18 walks set-identical to the system find, -exec, the two refusals) ok"
