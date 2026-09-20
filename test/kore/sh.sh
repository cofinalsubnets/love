#!/bin/sh
# test/kore/sh.sh -- sh -- lush aboard, through kore's door and the argv0 symlink
. "$(dirname "$0")/common.sh"

# lush rides the kore cat: `kore sh` (and an sh symlink) IS the shell -- the
# distro's /bin/sh. one -c through the image wake proves the whole ride:
# dispatch, compounds, cmdsub.
korerun sh -c 'if true; then echo "kore-sh $(echo ok)"; fi' > "$o" 2>&1; r=$?
[ $r -eq 0 ] && [ "$(cat "$o")" = "kore-sh ok" ] || fail "kore sh (exit $r)"
ln -sf .koreshim "$ho/sh"
"$ho/sh" -c 'echo via-symlink' > "$o" 2>&1; r=$?
[ $r -eq 0 ] && [ "$(cat "$o")" = "via-symlink" ] || fail "kore sh symlink (exit $r)"
echo "kore: sh (lush aboard -- kore sh + the argv0 symlink) ok"
