#!/bin/sh
# test/kore/sh.sh -- sh -- lush aboard, through kore's door and the argv0 symlink
. "$(dirname "$0")/common.sh"

# lush rides the kore cat: `kore sh` (and an sh symlink) IS the shell -- the
# distro's /bin/sh. one -c through the image wake proves the whole ride:
# dispatch, compounds, cmdsub.
korerun sh -c 'if true; then echo "kore-sh $(echo ok)"; fi' > "$o" 2>&1; r=$?
[ $r -eq 0 ] && [ "$(cat "$o")" = "kore-sh ok" ] || fail "kore sh (exit $r)"
printf '#!/bin/sh\nn=$(basename -- "$0")\nLOVE_NO_IMAGE= exec "%s" kore "$n" "$@"\n' "$PWD/$m" > "$ho/.koreshim"
chmod 755 "$ho/.koreshim"
ln -sf .koreshim "$ho/sh"
"$ho/sh" -c 'echo via-symlink' > "$o" 2>&1; r=$?
[ $r -eq 0 ] && [ "$(cat "$o")" = "via-symlink" ] || fail "kore sh symlink (exit $r)"
# stdin exact across a fork: a `while read` over a file whose body forks a love child
# (a ( ), a stage of ours in a pipeline) reads each line once, and a program exec'd
# after a `read` starts at the next line, not past what the shell read ahead
printf 'one\ntwo\nthree\n' > "$ho/.kore-sh-lines"
for body in '(true)' 'true | true' 'echo x | cat' '/usr/bin/env true'; do
  printf 'while read -r x; do echo "[$x]"; %s > /dev/null; done < %s\necho end\n' "$body" "$ho/.kore-sh-lines" > "$ho/.kore-sh-loop"
  [ "$(korerun sh -a "$ho/.kore-sh-loop" | tr '\n' ' ')" = "[one] [two] [three] end " ] \
    || fail "kore sh: a while-read loop around '$body' read a line twice"
done
if [ -x /usr/bin/head ]; then
  printf 'read -r a; /usr/bin/head -n 1; read -r b; echo "$a $b"\n' > "$ho/.kore-sh-rh"
  [ "$(korerun sh "$ho/.kore-sh-rh" < "$ho/.kore-sh-lines" | tr '\n' ' ')" = "two one three " ] \
    || fail "kore sh: an exec'd head after a read started in the wrong place"
fi
# kore's own head, in the image: it hands what it read ahead back to the port, so the
# shell's next read starts at the next line -- the line face and the byte face
printf 'read -r a; head -n 1; read -r b; echo "$a $b"\n' > "$ho/.kore-sh-rk"
[ "$(korerun sh -a "$ho/.kore-sh-rk" < "$ho/.kore-sh-lines" | tr '\n' ' ')" = "two one three " ] \
  || fail "kore sh: the in-image head after a read kept what it read ahead"
printf 'read -r a; head -c 4; read -r b; echo "$a $b"\n' > "$ho/.kore-sh-rk"
[ "$(korerun sh -a "$ho/.kore-sh-rk" < "$ho/.kore-sh-lines" | tr '\n' ' ')" = "two one three " ] \
  || fail "kore sh: the in-image head -c after a read kept what it read ahead"
echo "kore: sh (lush aboard -- kore sh + the argv0 symlink) ok"
