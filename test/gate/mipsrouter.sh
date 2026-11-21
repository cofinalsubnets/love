#!/bin/sh
# test/gate/mipsrouter.sh -- test_ccmips's hosted programs, the test/libc families they leave out,
# and test/holo/mipsbe.c and mipstp.c, on a big-endian mips linux box bee knows by mips-exec
# (doc/bee.md, HOSTS), each held to its own qemu-mips answer. qemu-user keeps the registers a real
# o32 syscall clobbers, and starts a program's thread pointer at 0 where a real kernel keeps the
# parent's, so only the box sees either.
# by hand, by name: the box is a router, so the binaries go to /tmp alone (bee --ship's scratch
# there) and nothing else on it is touched; what the programs leave in /tmp goes after
# usage: mipsrouter.sh LOVE OUTDIR
. test/gate/skip.sh
set -u

name=test_mips_router
love=$1
d=$2/cc-mips
fail() { echo "FAIL $name: $*"; exit 1; }

"$love" bee --on mips-exec --probe > /dev/null 2>&1 || gate_skip "$name: skipped (no host with mips-exec answers)"
command -v qemu-mips > /dev/null 2>&1 || gate_skip "$name: skipped (no qemu-mips for the answers)"
# the libc families test_ccmips's hosted set leaves out, from the same /tmp it runs them in
ad=$(cd "$d" && pwd)
for f in test/holo/mipsbe.c test/holo/mipstp.c test/libc/*.c; do
  b=${f##*/}; b=${b%.c}
  case $f in test/libc/inet.c|test/libc/port.c|test/libc/sig.c) continue ;; esac
  case $f in test/libc/*) [ -f "$d/$b.hout" ] && continue ;; esac
  "$love" mooncc -t mips -os linux -Itest/libc -o "$d/$b.h" "$f" > "$d/$b.hlog" 2>&1 || { cat "$d/$b.hlog"; fail "mooncc could not build $b.c"; }
  ( cd /tmp && { timeout 120 qemu-mips -cpu 24Kc "$ad/$b.h"; echo "rc $?"; } ) > "$d/$b.hout" 2>&1
done
sd=$2/mips-router
rm -rf "$sd"; mkdir -p "$sd/bin"
n=0
for o in "$d"/*.hout; do
  b=${o##*/}; b=${b%.hout}
  [ -f "$d/$b.h" ] || continue
  cp "$d/$b.h" "$sd/bin/$b"; n=$((n + 1))
done
[ $n -gt 50 ] || fail "only $n hosted programs in $d: run test_ccmips first"

# busybox has no timeout: a sleeping guard kills a program past 120 s
cat > "$sd/run.sh" <<'EOF'
for f in bin/*; do
  b=${f#bin/}
  echo "=== $b"
  ./$f < /dev/null 2>&1 & p=$!
  ( sleep 120; kill -9 $p 2>/dev/null ) & w=$!
  wait $p; r=$?
  kill $w 2>/dev/null
  echo "rc $r"
done
cd /tmp && rm -rf gexit?????? libc-port-?????? odds.?????? rbuf?????? lpath??????
uname -a | sed 's/^/=== uname /'
EOF
"$love" bee --on mips-exec --ship "$sd" -- sh run.sh > "$sd.out" 2>&1
rc=$?
[ $rc -eq 0 ] || { tail -5 "$sd.out"; fail "bee --on mips-exec answered $rc"; }

alike=0 diff=
for f in "$sd"/bin/*; do
  b=${f##*/}
  awk -v b="$b" '$0 == "=== " b { on = 1; next } /^=== / { on = 0 } on' "$sd.out" > "$sd/$b.out"
  if cmp -s "$d/$b.hout" "$sd/$b.out"; then alike=$((alike + 1))
  else diff="$diff $b"; echo "$b: qemu $(tail -1 "$d/$b.hout"), the box $(tail -1 "$sd/$b.out")"; diff "$d/$b.hout" "$sd/$b.out" | head -6; fi
done
box=$(sed -n 's/^=== uname //p' "$sd.out")
rm -rf "$sd" "$sd.out"
[ -z "$diff" ] || fail "the box answers otherwise than qemu-mips:$diff"
echo "$name: $alike of $n programs answer on the box as on qemu-mips ($box)"
