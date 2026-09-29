#!/bin/sh
# test/kore/diff.sh -- diff against GNU's unified body, argv0 dispatch, and the usage status
. "$(dirname "$0")/common.sh"

printf 'a\nb\nc\n' > "$ho/.au1"; printf 'a\nX\nc\n' > "$ho/.au2"
korerun diff "$ho/.au1" "$ho/.au1" > "$ho/.kore-same.out" 2>&1; r=$?
[ $r -eq 0 ] && [ ! -s "$ho/.kore-same.out" ] || fail "kore diff same (exit $r)"
korerun diff "$ho/.au1" "$ho/.au2" > "$ho/.kore-diff.out" 2>&1; r=$?
[ $r -eq 1 ] || fail "kore diff differ (exit $r)"
# the unified body must match GNU's; the ---/+++ header lines carry timestamps
diff -u "$ho/.au1" "$ho/.au2" | tail -n +3 > "$g"
tail -n +3 "$ho/.kore-diff.out" > "$o"
same "diff"
# -u is the face it already has; -q only says so; a stranger refuses with 2
korerun diff -u "$ho/.au1" "$ho/.au2" | tail -n +3 > "$o"; same "diff -u"
diff -q "$ho/.au1" "$ho/.au2" > "$g"; korerun diff -q "$ho/.au1" "$ho/.au2" > "$o"; r=$?
[ $r -eq 1 ] || fail "kore diff -q (exit $r)"; same "diff -q"
korerun diff -x "$ho/.au1" "$ho/.au2" > /dev/null 2>&1; r=$?; [ $r -eq 2 ] || fail "kore diff -x (exit $r)"
# kore dispatches on argv[0], so a link named `diff` IS diff. the shim is the distro's
# own shape (a script reading basename $0, tool names symlinked onto it) -- the build
# tree carries no kore binary anymore, the crew riding love's own image.
printf '#!/bin/sh\nn=$(basename -- "$0")\nLOVE_NO_IMAGE= exec "%s" kore "$n" "$@"\n' "$PWD/$m" > "$ho/.koreshim"
chmod 755 "$ho/.koreshim"
ln -sf .koreshim "$ho/diff"
"$ho/diff" "$ho/.au1" "$ho/.au2" > "$ho/.kore-sym.out" 2>&1; r=$?
[ $r -eq 1 ] && cmp -s "$ho/.kore-diff.out" "$ho/.kore-sym.out" \
  || fail "kore argv0 symlink (exit $r)"
korerun bogus > /dev/null 2>&1; r=$?
[ $r -eq 2 ] || fail "kore usage (exit $r)"
