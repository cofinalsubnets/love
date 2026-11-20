#!/bin/sh
# test/gate/libc.sh -- moonlibc against the system libc: each test/libc/*.c built by mooncc
# and by gcc, run, the outputs equal byte for byte. where the standard leaves a choice the
# programs print only the fixed part. then the headers' completeness, and REG_GREP vs gnu grep
# usage: libc.sh OUTDIR LOVE
. test/gate/skip.sh
. test/gate/cclib.sh
set -u

ho=$1
m=$2
d=$ho/libc
mkdir -p "$d"

name=test_libc

arch=$(uname -m)
# uname's spelling, not the tree's x64
if [ "$arch" != x86_64 ]; then
  gate_skip "test_libc: x86-64 only (mooncc emits x64), skipped on $arch"
fi
cc_g=$(command -v gcc || command -v cc) || true
if [ -z "${cc_g:-}" ]; then
  gate_skip "test_libc: no system cc for the second opinion, skipped"
fi

nfam=0
fams=
for f in test/libc/*.c; do
  b=$(basename "$f" .c)

  moonrun -Itest/libc -o "$d/$b" "$f" > "$d/$b.build" 2>&1 \
    || { cat "$d/$b.build" >&2; fail "$b: mooncc could not build it"; }
  "$d/$b" > "$d/$b.ours" 2>&1
  ra=$?
  { cat "$d/$b.ours"; echo "rc $ra"; } > "$d/$b.x64.out"

  # -w: gcc warns about deliberate edges (a truncating snprintf, a zero-length memset)
  $cc_g -O0 -w -Itest/libc -o "$d/$b.g" "$f" -lm 2> "$d/$b.gbuild" \
    || { cat "$d/$b.gbuild" >&2; fail "$b: the system cc could not build it"; }
  "$d/$b.g" > "$d/$b.theirs" 2>&1
  rg=$?

  [ $ra -eq $rg ] || fail "$b: exit ours $ra, $cc_g $rg"
  if ! cmp -s "$d/$b.ours" "$d/$b.theirs"; then
    echo "--- $b: ours vs $cc_g (first 20 differing lines) ---" >&2
    diff "$d/$b.theirs" "$d/$b.ours" 2>/dev/null | head -20 >&2
    fail "$b: our libc and the system's disagree"
  fi

  nfam=$((nfam + 1))
  fams="$fams $b"
done

[ $nfam -gt 0 ] || fail "no programs found in test/libc/"

# the same programs by mooncc's other backends under qemu: a64 and rv64 answer as x64 does,
# arm as rv32, the other ILP32
xisa() {
  t=$1 q=$2 ref=$3
  if ! have "$q"; then gate_partly "  (the $t leg skipped: no $q)"; return 0; fi
  for f in test/libc/*.c; do
    b=$(basename "$f" .c)
    moonrun -t "$t" -Itest/libc -o "$d/$b.$t" "$f" > "$d/$b.$t.build" 2>&1 \
      || { cat "$d/$b.$t.build" >&2; fail "$b: mooncc -t $t could not build it"; }
    { timeout 300 "$q" "$d/$b.$t"; echo "rc $?"; } > "$d/$b.$t.out" 2>&1
    if [ -n "$ref" ] && ! cmp -s "$d/$b.$ref.out" "$d/$b.$t.out"; then
      echo "--- $b: $t vs $ref (first 20 differing lines) ---" >&2
      diff "$d/$b.$ref.out" "$d/$b.$t.out" | head -20 >&2
      fail "$b: mooncc's $t and $ref disagree"
    fi
  done
}
xisa a64 qemu-aarch64 x64
xisa rv64 qemu-riscv64 x64
xisa rv32 qemu-riscv32 ''
if have qemu-riscv32; then xisa arm qemu-arm rv32; else gate_partly "  (the arm leg skipped: no rv32 to answer as)"; fi

# ---------------------------------------------------------------------------
# phase 2: every function any header declares is referenced by one generated program, so a
# declaration without a body fails the link
gen=$d/decls.c
names=$(hdrnames)
hdrdecls $names > "$gen"

nref=$(printf '%s\n' $names | grep -c .)
moonrun -o "$d/decls" "$gen" > "$d/decls.build" 2>&1 || {
  echo "--- the headers declare what moonlibc does not define ---" >&2
  grep -i "undef" "$d/decls.build" >&2 || cat "$d/decls.build" >&2
  fail "header/library completeness: $nref names declared, at least one has no body"
}

# ---------------------------------------------------------------------------
# phase 3: REG_GREP's matching lines per seeded pattern, against gnu grep -n's. no gnu grep, no phase
gg=
for x in /usr/bin/grep /bin/grep; do "$x" --version 2>/dev/null | grep -q GNU && { gg=$x; break; }; done
ng=0
if [ -n "$gg" ]; then
  moonrun -o "$d/regrep" test/libc/grep/regrep.c > "$d/regrep.build" 2>&1 \
    || { cat "$d/regrep.build" >&2; fail "regrep: mooncc could not build it"; }
  "$d/regrep" lines > "$d/regrep.lines"
  "$d/regrep" > "$d/regrep.ours" || fail "regrep: it did not run"
  tab=$(printf '\t')
  while IFS=$tab read -r fl p want; do
    # shellcheck disable=SC2086
    got=$(LC_ALL=C.UTF-8 "$gg" -a -n $fl -e "$p" "$d/regrep.lines" 2>/dev/null; echo "rc=$?")
    case $got in
      *rc=2) got=bad ;;
      *) got=$(printf '%s\n' "$got" | sed -n 's/^\([0-9]*\):.*/\1/p' | tr '\n' ,) ;;
    esac
    [ "$got" = "$want" ] || fail "regrep: grep $fl '$p': ours [$want], gnu grep [$got]"
    ng=$((ng + 1))
  done < "$d/regrep.ours"
fi

# ---------------------------------------------------------------------------
# phase 4: the waits on a weak memory. x86's exchange is a full barrier and hides an unlock
# that only acquires, so pthsync.c goes to an a64 host too: built for a64, run five times,
# and each run must print what the x64 build printed -- a mutex that leaks its holder's
# stores loses counts there. qemu orders as this machine does and proves nothing, so the leg
# wants a host.
. test/gate/a64run.sh
a64_how "$m"
nw=0
if [ "$a64_via" = host ]; then
  moonrun -t a64 -Itest/libc -o "$d/pthsync.a64" test/libc/pthsync.c > "$d/pthsync.a64.build" 2>&1 \
    || { cat "$d/pthsync.a64.build" >&2; fail "pthsync: mooncc could not build it for a64"; }
  a64_jobs "$d/wm"
  cp "$d/pthsync.a64" "$d/wm/pthsync"
  for i in 1 2 3 4 5; do a64_job "pt$i" '$RUN ./pthsync'; done
  a64_run "$d/wm" || fail "pthsync: the a64 host could not run it"
  for i in 1 2 3 4 5; do
    cmp -s "$d/wm/res/pt$i.out" "$d/pthsync.ours" || {
      diff "$d/pthsync.ours" "$d/wm/res/pt$i.out" | head -10 >&2
      fail "pthsync: run $i on the a64 host answered otherwise than x64"; }
    nw=$((nw + 1)); done
else
  gate_partly "test_libc: no a64 host for the weak-memory leg; skipped"
fi

echo "test_libc: moonlibc agrees with $cc_g's libc over$fams ($nfam families), defines all $nref names its headers declare, answers alike by mooncc's a64, rv64, rv32 and arm, reads $ng patterns as gnu grep does, and waits alike on a weak memory ($nw a64 runs)"
