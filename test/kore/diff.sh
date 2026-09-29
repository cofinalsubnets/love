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
# two trees, name by name: a file pair under its `diff FLAGS` row, Only in, Common
# subdirectories, a file against a directory, -r down, -N a missing side as empty, -q.
# GNU's ---/+++ rows carry times, and those are cut before the compare
D=$PWD/$ho/.difftree; ag=$PWD/$g; ao=$PWD/$o; M=$PWD/$m   # the rows are written from inside $D
 rm -rf "$D"; mkdir -p "$D/a/s/deep" "$D/b/s/deep" "$D/a/onlyd" "$D/b/x"
printf '1\n2\n' > "$D/a/f"; printf '1\n3\n' > "$D/b/f"; echo same > "$D/a/same"; echo same > "$D/b/same"
echo only > "$D/a/oa"; echo only > "$D/b/ob"; echo d > "$D/a/s/deep/g"; echo e > "$D/b/s/deep/g"
echo k > "$D/a/x"; echo q > "$D/a/onlyd/z"
for f in -u -ru -rq -q -ruN -rNq "-r -u"; do
  # shellcheck disable=SC2086
  (cd "$D" && diff $f a b | sed -E 's/^(---|\+\+\+) ([^	]*)	.*/\1 \2/' > "$ag"; LOVE_NO_IMAGE= "$M" kore diff $f a b > "$ao"; r=$?; [ $r -eq 1 ]) || fail "kore diff $f a b exit"
  same "diff $f a b"
done
(cd "$D" && diff -uN a/f nosuch | sed -E 's/^(---|\+\+\+) ([^	]*)	.*/\1 \2/' > "$ag"; LOVE_NO_IMAGE= "$M" kore diff -uN a/f nosuch > "$ao"); same "diff -N"
(cd "$D" && diff -u a/f b | tail -n +3 > "$ag"; LOVE_NO_IMAGE= "$M" kore diff -u a/f b | tail -n +3 > "$ao"); same "diff FILE DIR"
rm -rf "$D"
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
