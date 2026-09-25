#!/bin/sh
# ccbench.sh -- the compiler shootout (the page's fourth table). builds the love host
# binary with three C compilers and reports the wall-clock of each phase:
#   build             every C translation unit compiled and linked into a running `love`
#   test              the arch-neutral corpus ($t), egg-boot subtracted
#   chacha poly1305   one C function each (bench/ccrypto.l): an array-indexed inner loop
#                     beside a scalar-local one, which is where mooncc's register
#                     residency shows -- the pair is the reading, not either row
#   inflate crc32     the heavy nifs (bench/cnifs.l), three shapes: branchy, branchless,
#   sha256            and an array beside scalars. work the tree actually waits on.
# the lanes, all three static, which is the point of the pairing:
#   mooncc            love's own C compiler, run out of the shipped artifact's mooncc verb
#   gcc-musl          the same units at the host's -O2 cflags through the musl wrappers,
#   clang-musl        linked -static, egg-booting like mooncc so the field is level
# CCGLIBC=1 adds the old dynamic gcc/clang lanes alongside.
#
# emits "<phase> <compiler> <ms> <note>" (the satrace shape) for mkhtml; a failed lane
# reads dnf. wants `make host` first, for out/lib/*.h and the artifact the mooncc lane
# runs. x86-64 only for that lane; elsewhere its cells read dnf and the rest still race.
# the net row sums every phase, so results either side of a row change do not compare.
#
# absolute: the build lanes cd into the root, so every path below has to survive that
R=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TIMEOUT=${1:-180}
SAMPLES=${2:-3}
ho=$R/out
WORK=$R/out/bench/cc
rm -rf "$WORK"; mkdir -p "$WORK"

# a distro's ccache shim would clock a cache hit, and mooncc has no cache to hit
export CCACHE_DISABLE=1

# common.mk's `t`, byte for byte: the three front-loaded, then the rest in byte order
# (glaze-x86 out -- it wants emit.l ahead of it and runs native under its own guard)
CORPUS=${CORPUS:-"$R/test/00-init.l $R/test/spec.l $R/test/uu.l $(ls "$R"/test/*.l 2>/dev/null | grep -vE '/(00-init|spec|glaze-x86|uu)\.l$' | LC_ALL=C sort)"}

# the Makefile's $(cflags) and nowhere else: a copy here drifts, and a table timed
# under flags that are not the tree's is wrong rather than missing
[ -n "${LOVE_CFLAGS:-}" ] || { echo "ccbench: no LOVE_CFLAGS -- run \`make ccbench\`" >&2; exit 2; }
# a caller's -Werror comes back out: a warning set is not throughput
CFLAGS="$(printf '%s' "$LOVE_CFLAGS" | sed 's/-Werror//g') -Dai_tco=1 -fpic -I$ho -I$R -I$R/love -I$R/inle -I$R/out/lib"
# the hosted roster, common.mk's spelling: love/ plus inle/ less the kernel's own six
love_tu="love gc ev task io map snap num arr gz"
host_cs=$(ls "$R"/inle/*.c | grep -v '/\(kmain\|blk\|hda\|sys\|doom\|doomsnd\)\.c$')
# common.mk's $(data_ld), owed by any link: the sentinels' tiling is love.h's ai_typ, and
# ld left alone orders love.data.N as emitted -- lvm_str under lvm_sym, strings as closures
LDFLAGS="-Wl,-T,$R/love/love_data.ld"

# wall-clock ms of a command, in a subshell so a cd cannot leak
wall() { t0=$(date +%s.%N); ( eval "$1" ) >/dev/null 2>&1; t1=$(date +%s.%N)
         awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f",(b-a)*1000}'; }
med() { i=0; while [ "$i" -lt "$SAMPLES" ]; do wall "$1"; echo; i=$((i+1)); done \
        | sort -n | awk '{v[NR]=$0} END{print v[int((NR+1)/2)]}'; }

build_cc() { # $1=compiler $2=binpath $3=extra flags ; objects under $WORK/o-<binname>
  cc=$1; bin=$2; xf=$3; od=$WORK/o-$(basename "$bin")   # o- prefix: $bin itself lives in $WORK
  rm -rf "$od"; mkdir -p "$od/host"
  ( cd "$R" || exit 1
    for b in $love_tu; do
      $cc $CFLAGS $xf -c "love/$b.c" -o "$od/$b.o" || exit 1; done
    $cc $CFLAGS $xf -c apps/moon/lib/moonlibc/math/am.c -o "$od/am.o" || exit 1
    for f in $host_cs; do b=$(basename "$f" .c)
      $cc $CFLAGS $xf -c "$f" -o "$od/host/$b.o" || exit 1; done
    $cc $CFLAGS $xf $LDFLAGS -o "$bin" "$od"/*.o "$od"/host/*.o ) || return 1
}

# mooncc: the whole toolchain in love, as `make test_raw` spells it -- a -c per unit,
# mksys for the syscall leaf, our own linker. the compiler is the shipped artifact
# because that is what a user runs, and its libc archive caches under ~/.love/cache/moon
# keyed on a baked image, so intermediates rebuilding does not re-pay the build.
# LOVE_NO_IMAGE= is empty, not unset: an egg-booted love has no verb table, so `mooncc`
# would read as a filename.
SEED=$R/out/love
mc() { env LOVE_NO_IMAGE= "$SEED" mooncc "$@"; }
build_mooncc() { # $1=binpath
  bin=$1; od=$WORK/mooncc; rm -rf "$od"; mkdir -p "$od"
  ( cd "$R" || exit 1
    for b in $love_tu; do
      mc -D ai_tco=1 -D LvHaveVersionH -Iout -I. -Ilove -Iinle -Iout/lib -c "love/$b.c" "$od/$b.o" || exit 1; done
    for f in $host_cs; do b=$(basename "$f" .c)
      mc -D ai_tco=1 -D LvHaveVersionH -Iout -I. -Ilove -Iinle -Iout/lib -c "$f" "$od/host_$b.o" || exit 1; done
    # no moonlibc object: the link pulls members by need, so ccsize and ccdead read
    # mooncc's libc off the binary's complement instead
    for f in apps/moon/lib/moonlibc/math/*.c; do b=$(basename "$f" .c)
      mc -Iapps/moon/lib/moonlibc/math -Iapps/moon/include -c "$f" "$od/m_$b.o" || exit 1; done
    { cat apps/kore/text.l apps/kore/u.l apps/kore/asbook.l \
          love/holo/elf.l love/holo/obj.l apps/moon/lib/mksys.l
      echo "((cite 'moon 'mksys-x64) \"$od/sys.o\")"; } | env LOVE_NO_IMAGE= "$SEED" || exit 1
    mc "$od"/*.o -o "$bin" ) || return 1
}

# one file by redirect, not a pipe: only a seekable fd 0 gets a read run (inle/main.c),
# and a pipe's read-per-byte is kernel time in every lane alike, diluting the reading
CORPUS1=$WORK/corpus.l
cat $CORPUS > "$CORPUS1"

# exit 0 AND the sentinel: a binary that reader-stops mid-corpus must not be timed. the
# corpus runs from the root, as the gates run it: a test borrows a module by its tree path
passes() { out=$(cd "$R" && LOVE_NO_IMAGE=1 timeout "$TIMEOUT" "$1" < "$CORPUS1" 2>&1); r=$?
           [ $r -eq 0 ] && printf '%s' "$out" | grep -q "tests pass"; }

# the corpus alone: every fresh binary egg-boots, so an empty run is subtracted and the
# fixed seconds cancel. all three lanes egg-boot, which is what keeps the field level.
corpus_ms() { # $1=binpath ; median full, median boot, report max(0, full-boot)
  bin=$1
  full=$(med "cd $R && LOVE_NO_IMAGE=1 $bin < $CORPUS1")
  boot=$(med "cd $R && LOVE_NO_IMAGE=1 $bin </dev/null")
  awk -v f="$full" -v b="$boot" 'BEGIN{d=f-b; printf "%.1f", d<0?0:d}'
}

# a driver's run time, boot subtracted the same way; the reps are fixed in the .l.
# no sentinel is dnf: a lane that answered nothing must not be timed as if it were fast.
CRYPTO=$R/bench/ccrypto.l
NIFS=$R/bench/cnifs.l
drv_ms() { # $1=binpath $2=driver-file $3=driver-call $4=sentinel
  bin=$1; df=$2; drv=$3
  { cat "$df"; echo "$drv"; } > "$WORK/drv.run.l"
  out=$(LOVE_NO_IMAGE=1 timeout "$TIMEOUT" "$bin" < "$WORK/drv.run.l" 2>&1) || { echo dnf; return; }
  printf '%s' "$out" | grep -q "$4" || { echo dnf; return; }
  full=$(med "LOVE_NO_IMAGE=1 $bin < $WORK/drv.run.l")
  boot=$(med "LOVE_NO_IMAGE=1 $bin </dev/null")
  awk -v f="$full" -v b="$boot" 'BEGIN{d=f-b; printf "%.1f", d<0?0:d}'
}

# the inflate row's input, laid by the host love: apps/gz.l is a module and the lane
# binaries have no module path. INFN is the inflated size; 0 leaves that one row dnf.
INF=$WORK/bench.deflate
INFN=$(cd "$R" && out/love bench/ccgen.l love/love.c "$INF" 2>/dev/null)
case $INFN in ''|*[!0-9]*) INFN=0;; esac

# one lane: build timed once, verified, then every row with boot subtracted
lane() { # $1=label $2=builder-cmd $3=binpath $4=extra cflags (build_cc only)
  lbl=$1; bld=$2; bin=$3
  bt=$(wall "$bld '$bin' '$4'")
  if [ ! -f "$bin" ] || [ ! -x "$bin" ]; then dnf_lane "$lbl"; return; fi
  echo "build $lbl $bt ok"; LIVE=$((LIVE + 1))            # the liveness tally, read at the end
  if passes "$bin"; then echo "test $lbl $(corpus_ms "$bin") ok"
  else echo "test $lbl dnf"; fi
  crow chacha   "$lbl" "$(drv_ms "$bin" "$CRYPTO" '(cc-run ())' 'ccrypto chacha: ok')"
  crow poly1305 "$lbl" "$(drv_ms "$bin" "$CRYPTO" '(po-run ())' 'ccrypto poly1305: ok')"
  if [ "$INFN" -gt 0 ]; then
    crow inflate "$lbl" "$(drv_ms "$bin" "$NIFS" "(inf-run \"$INF\" $INFN 300)" 'cnifs inflate: ok')"
  else echo "inflate $lbl dnf"; fi
  crow crc32    "$lbl" "$(drv_ms "$bin" "$NIFS" '(crc-run ())' 'cnifs crc32: ok')"
  crow sha256   "$lbl" "$(drv_ms "$bin" "$NIFS" '(sha-run ())' 'cnifs sha256: ok')"
}
crow() { case $3 in dnf) echo "$1 $2 dnf";; *) echo "$1 $2 $3 ok";; esac; }
dnf_lane() { for ph in build test chacha poly1305 inflate crc32 sha256; do echo "$ph $1 dnf"; done; }

# a broken harness renders as a well-formed table of dnf. one missing compiler is a
# skip; zero live lanes is this script's own fault, and it exits 1 at the foot.
LIVE=0

if [ "$(uname -m)" = x86_64 ] && [ -x "$SEED" ]; then
  # one untimed build first: gcc and clang link a musl someone else compiled, so mooncc's
  # own libc is built here rather than inside the timed row
  build_mooncc "$WORK/love-warm" >/dev/null 2>&1
  lane mooncc build_mooncc "$WORK/love-mooncc"
else
  dnf_lane mooncc                        # x86-64 only, and it needs the artifact built
fi
# static musl: the same units, only the libc differs -- and -static puts it inside the
# binary, where mooncc's moonlibc already is
for c in gcc clang; do
  if command -v "musl-$c" >/dev/null 2>&1; then
    lane "$c-musl" "build_cc musl-$c" "$WORK/love-$c-musl" -static
  else
    dnf_lane "$c-musl"
  fi
done
# the old dynamic-glibc lanes, for continuity with fills that predate the switch
if [ -n "$CCGLIBC" ]; then
  for c in gcc clang; do
    if command -v "$c" >/dev/null 2>&1; then
      lane "$c" "build_cc $c" "$WORK/love-$c"
    else
      dnf_lane "$c"
    fi
  done
fi

[ "$LIVE" -gt 0 ] || { echo "ccbench: every lane dnf -- the harness, not the compilers" >&2
                       exit 1; }
