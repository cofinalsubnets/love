#!/bin/sh
# test/gate/ccbat.sh -- the C battery on a target: every test/cc/*.c built by `mooncc -t TARGET`,
# plain and -Os, must answer as its references do: our x86-64 build, the target's compiler, or
# both. the binaries are built, run as one batch ($RUN before each, on a host for a64), compared.
# the lists, each held to what it says:
#   refuse  mooncc has no lane: it refuses, by name, without a signal
#   wide    not C on ilp32 (a static assert, a bit-field past its type): both refuse
#   narrow  assumes a 64-bit long: the reference fails it, ours runs it to an exit
#   w128    __int128, which the target's gcc has no lane for: the host cc's build is the reference
#   hosted  the reference's libc has gaps, or reads frames otherwise: ours runs it to an exit
#   nolibc  no libc on the board: at least one of the two links fails
#   skip    not held to anything here: assumes a 64-bit long, or no witness
#   nogcc   held to x86-64 alone
#   gnopie  an address as an "i" operand: gcc wants no pie
# usage: ccbat.sh TARGET OUTDIR LOVE   (TARGET: a64 rv64 wasm arm i386 thumb1 thumb2)
. test/gate/skip.sh
. test/gate/a64run.sh
. test/gate/cclib.sh
. test/gate/thumbrt.sh
set -u

tgt=$1
ho=$2
m=$3
name=test_cc$tgt
pretty=$tgt
x64ref=
exitonly=
mflags=
gext=
grun='$RUN'
mach=
GCC=
refuse=
wide=
narrow=
hosted=
w128=
nolibc=
skip=
nogcc=
gnopie=
d=${ho:?}/cc-$tgt
rm -rf "${d:?}"
mkdir -p "$d"

inlist() { for w in $2; do [ "$w" = "$1" ] && return 0; done; return 1; }
first() { for c in "$@"; do command -v "$c" 2>/dev/null && return 0; done; return 0; }
need() { for t in "$@"; do have "$t" || gate_skip "$name: no $t, skipped"; done; }
# a cross gcc with a static libc
gstatic() {
  gf=; inlist "$(basename "$2" .c)" "$gnopie" && gf="-fno-pie -no-pie"
  $GCC -O0 -w -static $gf -o "$1" "$2"
}
a64_via=qemu
int128s="111-int128 151-w128fuzz 314-u128union 352-u128abi"
narrow32="105-fneg 144-gnubuiltins 152-rotate 266-vaarg-struct"

case $tgt in
  a64)
    a64_how "$m"
    [ -n "$a64_via" ] || gate_skip "$name: skipped (need qemu-aarch64 or an a64 host)"
    x64ref=1
    GCC=${AARCH64_CC:-}
    [ -n "$GCC" ] || GCC=$(first aarch64-linux-gnu-gcc a64-nerves-linux-gnu-gcc)
    [ -n "$GCC" ] || GCC=$(ls /usr/local/data/*/.nerves/artifacts/nerves_toolchain_a64*/bin/a64-nerves-linux-gnu-gcc 2>/dev/null | head -1)
    gnopie="181-asmaddr 242-asmprel64"
    # gcc 16 lays a64's frame record under the locals, and its frame chain above level 0 is its own
    nogcc="160-rangeinit 297-frameaddr"
    gref() { gstatic "$@"; } ;;
  rv64)
    a64_qemu=$(first qemu-riscv64)
    [ -n "$a64_qemu" ] || gate_skip "$name: skipped (need qemu-riscv64)"
    x64ref=1
    GCC=${RISCV64_CC:-}
    [ -n "$GCC" ] || GCC=$(first riscv64-linux-gnu-gcc riscv64-unknown-linux-gnu-gcc riscv64-unknown-elf-gcc)
    refuse="$int128s 297-frameaddr"
    gref() { gstatic "$@"; } ;;
  wasm)
    NODE=$(first node)
    [ -n "$NODE" ] || gate_skip "$name: skipped (need node)"
    a64_qemu="$NODE $PWD/src/inle/wasm/loader.js"
    x64ref=1
    GCC=${EMCC:-$(first emcc)}
    [ -n "$GCC" ] || [ ! -x /usr/lib/emscripten/emcc ] || GCC=/usr/lib/emscripten/emcc
    grun=$NODE
    gext=.js
    # return addresses, frame chains and label values live off linear memory, longjmp has no
    # unwind to ride, and a module has no symbol table for 294's asm labels
    refuse="$int128s 160-rangeinit 229-labelvalue 256-inline-retaddr 294-asmlabel 297-frameaddr 345-jmpsave"
    # clang lacks __builtin_*_overflow_p, emcc's malloc aborts where C answers NULL, its
    # aligned_alloc keeps C11's size rule, its __divsc3 isn't libgcc's
    nogcc="268-overflow-p 298-malloc-wrap 300-aligned-alloc 280-cxf-fuzz"
    gref() { "$GCC" -sMEMORY64=1 -O0 -w -o "$1" "$2"; } ;;
  arm)
    need arm-none-eabi-gcc qemu-arm
    a64_qemu=qemu-arm
    GCC=arm-none-eabi-gcc
    refuse="161-enumwide"
    w128=$int128s
    wide="68-static-assert 120-bfinit"
    narrow=$narrow32
    hosted="72-quals 125-widelit 150-alloc 160-rangeinit 297-frameaddr 298-malloc-wrap 300-aligned-alloc 301-free-checks 348-libcmore"
    gref() { arm-none-eabi-gcc -mcpu=cortex-a53 -mthumb -mfloat-abi=hard -mfpu=fp-armv8 --specs=rdimon.specs -O1 -w -o "$1" "$2" -lm; } ;;
  i386)
    a64_qemu=
    GCC="gcc -m32"
    refuse=$int128s
    wide="68-static-assert 120-bfinit 161-enumwide"
    narrow=$narrow32
    gref() { gcc -m32 -msse2 -mfpmath=sse -w -o "$1" "$2" -lm; } ;;
  thumb1|thumb2)
    thumb_board $tgt "$d"
    if [ $tgt = thumb1 ]; then
      refuse="68-static-assert $int128s 129-sync 161-enumwide"
    else
      refuse="68-static-assert 161-enumwide"
    fi
    a64_qemu="qemu-system-arm -M $mach -semihosting -nographic -kernel"
    pretty="qemu $mach"
    GCC=arm-none-eabi-gcc
    exitonly=1
    mflags="-Dmain=cc_main -c"
    nolibc="356-vafnval 72-quals 110-param5 114-rmwlv 134-tentative 135-uac 142-syntax 146-declscope 147-enumscope 148-tagscope 149-paste 150-alloc 154-blockextern 158-gnukw 159-stmtexpr 160-rangeinit 162-constexpr 163-bitfields 164-switchtab 315-alloca-stack 298-malloc-wrap 115-rmwop 165-constcond 166-condconv 283-splitsexpr 228-strictalign 111-int128 151-w128fuzz 314-u128union 352-u128abi 300-aligned-alloc 301-free-checks 302-realloc-grow 303-arena-churn 304-size-classes 345-jmpsave 348-libcmore 353-intuint 355-cplxarg"
    # assumes a 64-bit long; gcc's arm build follows no frame chain past level 1, so no witness for 297
    skip="354-idioms 81-builtins 99-muslimage 104-u32wrap 105-fneg 120-bfinit 125-widelit 144-gnubuiltins 266-vaarg-struct 297-frameaddr"
    # main is renamed cc_main for `run`; mem* and strcmp are the floor a compiler may call
    { echo 'int cc_main(void);'
      echo 'int run(void){ return cc_main(); }'
      echo 'void *memset(void *p, int c, unsigned long n){'
      echo ' unsigned char *q = p; while (n--) *q++ = (unsigned char) c; return p; }'
      echo 'void *memcpy(void *a, const void *b, unsigned long n){'
      echo ' unsigned char *x = a; const unsigned char *y = b; while (n--) *x++ = *y++; return a; }'
      echo 'void *memmove(void *a, const void *b, unsigned long n){'
      echo ' unsigned char *x = a; const unsigned char *y = b;'
      echo ' if (x < y) { while (n--) *x++ = *y++; }'
      echo ' else { x += n; y += n; while (n--) *--x = *--y; } return a; }'
      echo 'int strcmp(const char *a, const char *b){'
      echo ' while (*a && *a == *b) a++, b++; return (unsigned char) *a - (unsigned char) *b; }'
    } > "$d/run.c"
    arm-none-eabi-gcc $cpu -ffreestanding -O2 -c "$d/run.c" -o "$d/run.o" || fail "gcc run.c"
    blink() { arm-none-eabi-ld -T "$d/link.ld" "$d/start.o" "$d/run.o" "$1" "$lg" -o "$2"; }
    gref() {
      arm-none-eabi-gcc $cpu -O0 -w -ffreestanding -Dmain=cc_main -c "$2" -o "$1.o" && blink "$1.o" "$1"
    } ;;
  *) echo "ccbat.sh: unknown target $tgt" >&2; exit 1 ;;
esac
[ "$(uname -m)" = x86_64 ] || [ -z "$x64ref" ] || gate_skip "$name: skipped (the reference build is native x86-64)"
[ "$(uname -m)" = x86_64 ] || [ "$tgt" != i386 ] || gate_skip "$name: skipped (runs i386 binaries natively on x86-64)"
case $tgt in
  arm|i386)
    printf '#include <stdio.h>\nint main(void){puts("ok");return 0;}\n' > "$d/probe.c"
    gref "$d/probe" "$d/probe.c" > /dev/null 2>&1 && [ "$($a64_qemu "$d/probe")" = ok ] \
      || gate_skip "$name: skipped ($GCC cannot build and run a hello here)" ;;
esac
where=$([ "$a64_via" = host ] && echo "on an a64 host" || echo "on $pretty")

# a program's own flags, off its first line: /* mooncc -t ARCH: FLAGS */; x64 builds without
tflags() { sed -n "1s|^/\* mooncc -t $tgt: \(.*\) \*/\$|\1|p" "$1"; }
# ours: compile $2 to $1 with flags $3.., a board's object linked
ours() {
  o=$1; f=$2; shift 2
  moonrun -t "$tgt" $mflags $(tflags "$f") "$@" -o "$o" "$f" || return 1
  [ -z "$exitonly" ] || { mv "$o" "$o.o" && blink "$o.o" "$o"; }
}

r=$d/run
a64_jobs "$r"
nref=0; nwide=0; nnar=0; nhost=0; nlibc=0; nskip=0
progs=
for f in test/cc/*.c; do
  b=$(basename "$f" .c)
  if inlist "$b" "$refuse"; then
    refused "$d/$b.tlog" "$f" -t "$tgt" $mflags -o "$d/$b.t" "$f"
    nref=$((nref + 1)); continue
  fi
  if inlist "$b" "$wide"; then
    gref "$d/$b.g" "$f" > "$d/$b.glog" 2>&1 && fail "$b: $GCC builds a program listed as wide -- take it off the list"
    refused "$d/$b.tlog" "$f" -t "$tgt" -o "$d/$b.t" "$f"
    nwide=$((nwide + 1)); continue
  fi
  if inlist "$b" "$skip"; then nskip=$((nskip + 1)); continue; fi
  if inlist "$b" "$nolibc"; then
    ours "$d/$b.t" "$f" > "$d/$b.tlog" 2>&1 && gref "$d/$b.g" "$f" > "$d/$b.glog" 2>&1 \
      && fail "$b: listed as nolibc, but both sides built and linked freestanding -- take it off the list"
    nlibc=$((nlibc + 1)); continue
  fi

  if [ -n "$x64ref" ]; then
    moonrun -o "$d/$b.x" "$f" > "$d/$b.xlog" 2>&1 \
      || { cat "$d/$b.xlog" >&2; fail "$b: mooncc could not build the x86-64 reference"; }
    timeout 60 "$d/$b.x" > "$d/$b.xout" 2>&1; echo $? > "$d/$b.xrc"
  fi

  for os in t s; do
    fl=; [ $os = s ] && fl=-Os
    ours "$r/$b.$os" "$f" $fl > "$d/$b.${os}log" 2>&1 \
      || { cat "$d/$b.${os}log" >&2; fail "$b: mooncc -t $tgt $fl could not build it -- a new refusal, or a name for refuse="; }
    a64_job "$b.$os" "timeout 60 \$RUN ./$b.$os"
  done

  if inlist "$b" "$w128"; then
    cc -w -O1 -o "$r/$b.g" "$f" > "$d/$b.glog" 2>&1 || { cat "$d/$b.glog" >&2; fail "$b: the host cc could not build it"; }
    a64_job "$b.g" "timeout 60 ./$b.g"
  elif [ -n "$GCC" ] && ! inlist "$b" "$nogcc $hosted"; then
    gref "$r/$b.g$gext" "$f" > "$d/$b.glog" 2>&1 \
      || { cat "$d/$b.glog" >&2; fail "$b: $GCC could not build it"; }
    a64_job "$b.g" "timeout 60 $grun ./$b.g$gext"
  fi
  progs="$progs $b"
done

# what a target holds beside the battery
if [ $tgt = a64 ]; then
  # the packed program again under -mstrict-align
  moonrun -t a64 -mstrict-align -o "$r/sa279.t" test/cc/279-packed-bitfield.c > "$d/sa279.log" 2>&1 \
    || { cat "$d/sa279.log" >&2; fail "strict-align: mooncc could not build 279-packed-bitfield.c"; }
  a64_job sa279.t "timeout 60 \$RUN ./sa279.t"

  # abi64/host.c by mooncc linked with clang's peer.c, each calling the other
  command -v clang > /dev/null 2>&1 || gate_skip "$name: no clang for the abi64 half"
  clang --target=aarch64-linux-gnu -O2 -ffreestanding -fno-stack-protector -c -o "$d/peer.o" test/cc/abi64/peer.c 2> "$d/peer.log" \
    || { cat "$d/peer.log" >&2; fail "abi64: clang could not build peer.c"; }
  moonrun -t a64 -o "$r/abi64.t" test/cc/abi64/host.c "$d/peer.o" > "$d/abi64.log" 2>&1 \
    || { cat "$d/abi64.log" >&2; fail "abi64: mooncc could not build or link host.c"; }
  a64_job abi64.t "timeout 60 \$RUN ./abi64.t"
  # __int128 across them: the even register pair, the 16-aligned stack pair
  clang --target=aarch64-linux-gnu -O2 -ffreestanding -fno-stack-protector -c -o "$d/peer128.o" test/cc/abi128/peer.c 2> "$d/peer128.log" \
    || { cat "$d/peer128.log" >&2; fail "abi128: clang could not build peer.c"; }
  moonrun -t a64 -o "$r/abi128.t" test/cc/abi128/host.c "$d/peer128.o" > "$d/abi128.log" 2>&1 \
    || { cat "$d/abi128.log" >&2; fail "abi128: mooncc could not build or link host.c"; }
  a64_job abi128.t "timeout 60 \$RUN ./abi128.t"
  # thread-locals: clang's at -O0 and -O2 under mooncc's link and moonlibc's threads, a
  # program calling no libc, and every load and store width's offset (ldst64.s)
  clang --target=aarch64-linux-gnu -fno-pie -c -o "$d/tlsd.o" test/cc/tls/defs.c 2> "$d/tls.log" \
    || { cat "$d/tls.log" >&2; fail "tls: clang could not build defs.c"; }
  for o in 0 2; do
    clang --target=aarch64-linux-gnu -O$o -fno-pie -c -o "$d/tlsp$o.o" test/cc/tls/peer.c 2> "$d/tls.log" \
      || { cat "$d/tls.log" >&2; fail "tls: clang -O$o could not build peer.c"; }
    moonrun -t a64 -no-pie -Wl,-z,noexecstack -o "$r/tls$o.t" test/cc/tls/host.c "$d/tlsp$o.o" "$d/tlsd.o" > "$d/tls.log" 2>&1 \
      || { cat "$d/tls.log" >&2; fail "tls: mooncc could not link clang -O$o's thread-locals"; }
    a64_job tls$o.t "timeout 60 \$RUN ./tls$o.t"
  done
  moonrun -t a64 -o "$r/tlsb.t" test/cc/tls/bare.c "$d/tlsp2.o" "$d/tlsd.o" > "$d/tls.log" 2>&1 \
    || { cat "$d/tls.log" >&2; fail "tls: mooncc could not link bare.c"; }
  a64_job tlsb.t "timeout 60 \$RUN ./tlsb.t"
  clang --target=aarch64-linux-gnu -c -o "$d/ldst64.o" test/cc/tls/ldst64.s 2> "$d/tls.log" \
    || { cat "$d/tls.log" >&2; fail "tls: clang could not assemble ldst64.s"; }
  moonrun -t a64 -o "$r/ldst64.t" test/cc/tls/ldst64.c "$d/ldst64.o" > "$d/tls.log" 2>&1 \
    || { cat "$d/tls.log" >&2; fail "tls: mooncc could not link ldst64.s"; }
  a64_job ldst64.t "timeout 60 \$RUN ./ldst64.t"

  # the landing law, against clang on protect/units.c: each fn's landing, autiasp before
  # every exit and after every frame record's ldp, no packed access wider, the notes equal
  hc=${HEARTS_CLANG:-$HOME/.cache/hearts/llvm-22.1.8}/bin/clang
  [ -x "$hc" ] || hc=clang
  command -v llvm-objdump > /dev/null 2>&1 && command -v llvm-readelf > /dev/null 2>&1 \
    || gate_skip "$name: no llvm-objdump or llvm-readelf for the landing law"
  bp="-mbranch-protection=pac-ret+bti -mstrict-align"
  "$hc" --target=aarch64-linux-gnu -O2 $bp -c -o "$d/land.c.o" test/cc/protect/units.c 2> "$d/land.log" \
    || { cat "$d/land.log" >&2; fail "landing: clang could not build units.c"; }
  moonrun -t a64 -c $bp -o "$d/land.m.o" test/cc/protect/units.c > "$d/land.log" 2>&1 \
    || { cat "$d/land.log" >&2; fail "landing: mooncc could not build units.c"; }
  # L fn landing | W fn widest-packed-access | BAD fn why
  land() {
    llvm-objdump -dr --no-show-raw-insn "$1" | awk '
      function wd(m, ops,   r) {
        if (m ~ /^(ld|st)(u?r|ur)s?b$/ || m ~ /^ldu?rsb$/) return 1
        if (m ~ /^(ld|st)(u?r|ur)s?h$/ || m ~ /^ldu?rsh$/) return 2
        if (m ~ /^ldu?rsw$/) return 4
        r = substr(ops, 1, 1)
        return r == "x" || r == "d" ? 8 : r == "q" ? 16 : r == "h" ? 2 : r == "b" ? 1 : 4
      }
      function out() { if (fn ~ /^pk_/) print "W", fn, w }
      /^[0-9a-f]+ </ { if (fn != "") out(); fn = $2; gsub(/[<>:]/, "", fn); first = 1; pac = 0; w = 0; prev = ""; pprev = ""; ldp = 0; next }
      /R_AARCH64_JUMP26/ { if (pac && prev ~ /^b\t/ && pprev != "autiasp") print "BAD", fn, "a tail branch without autiasp"; next }
      /^ +[0-9a-f]+:/ {
        l = $0; sub(/^ +[0-9a-f]+:[ \t]+/, "", l); sub(/[ \t]*(\/\/|<).*$/, "", l)
        if (first) { c = l == "bti\tc" ? "btic" : l == "paciasp" ? "pac" : "-"; print "L", fn, c; pac = c == "pac"; first = 0 }
        if (pac && (l == "ret" || l ~ /^br\t/) && prev != "autiasp") print "BAD", fn, "an exit without autiasp: " l
        if (ldp && l != "autiasp") print "BAD", fn, "a frame record restored without autiasp"
        ldp = l ~ /^ldp\tx29, x30/
        split(l, f, "\t"); m = f[1]
        if (m ~ /^(ld|st)(u?r|p)/ && m !~ /x(r|p)$/ && match(l, /\[[a-z0-9]+/)) {
          b = substr(l, RSTART + 1, RLENGTH - 1)
          if (b != "sp" && b != "x29") { k = wd(m, f[2]); if (k > w) w = k }
        }
        pprev = prev; prev = l
      }
      END { if (fn != "") out() }'
  }
  land "$d/land.c.o" > "$d/land.c"
  land "$d/land.m.o" > "$d/land.m"
  grep '^BAD' "$d/land.m" >&2 && fail "landing: mooncc's exits (above)"
  grep '^L' "$d/land.c" | sort > "$d/land.cl"
  grep '^L' "$d/land.m" | sort > "$d/land.ml"
  cmp -s "$d/land.cl" "$d/land.ml" || { diff "$d/land.cl" "$d/land.ml" >&2; fail "landing: a fn lands where clang's does not (clang <, mooncc >)"; }
  grep '^W' "$d/land.m" | while read -r _ fn k; do
    kc=$(grep "^W $fn " "$d/land.c" | cut -d' ' -f3)
    [ "$k" -le "${kc:-0}" ] || { echo "landing: $fn reads $k bytes at once where clang reads $kc" >&2; exit 1; }
  done || fail "landing: a packed access wider than clang's"
  for s in .note.gnu.property .ARM.attributes; do
    llvm-readelf -x $s "$d/land.c.o" | grep '^ *0x' > "$d/land.cs"
    llvm-readelf -x $s "$d/land.m.o" | grep '^ *0x' > "$d/land.ms"
    [ -s "$d/land.cs" ] && cmp -s "$d/land.cs" "$d/land.ms" \
      || { diff "$d/land.cs" "$d/land.ms" >&2; fail "landing: $s differs from clang's"; }
  done
  echo "landing: $(grep -c '^L' "$d/land.m") fns land as clang $("$hc" --version | sed -n '1s/.*version //p')'s do, their exits authenticate, packed reads go by its widths, the notes match"
fi

a64_run "$r" || fail "the $pretty batch did not come back"

if [ $tgt = a64 ]; then
  [ "$(cat "$r/res/sa279.t.rc")" -eq 0 ] || { cat "$r/res/sa279.t.out" >&2; fail "strict-align: 279-packed-bitfield.c answers wrong under -mstrict-align"; }
  [ "$(cat "$r/res/abi64.t.rc")" -eq 0 ] || { cat "$r/res/abi64.t.out" >&2; fail "abi64: mooncc and clang disagree on AAPCS64"; }
  tail -1 "$r/res/abi64.t.out"
  [ "$(cat "$r/res/abi128.t.rc")" -eq 0 ] || { cat "$r/res/abi128.t.out" >&2; fail "abi128: mooncc and clang disagree on AAPCS64's __int128"; }
  tail -1 "$r/res/abi128.t.out"
  for t in tls0 tls2 tlsb ldst64; do
    [ "$(cat "$r/res/$t.t.rc")" -eq 0 ] || { cat "$r/res/$t.t.out" >&2; fail "tls: $t answers $(cat "$r/res/$t.t.rc") $where"; }
  done
  readelf -lW "$r/tls2.t" | grep -q ' TLS ' || fail "tls: the a64 link laid no PT_TLS"
  echo "tls: clang's thread-locals read right $where, -O0 and -O2, two threads, no libc, every width"
fi
if [ $tgt = i386 ]; then
  # abi386/host.c by mooncc linked with gcc's peer.c, each calling the other, -mregparm 0..3
  for rp in 0 1 2 3; do
    gcc -m32 -mregparm=$rp -O1 -w -c -o "$d/peer$rp.o" test/cc/abi386/peer.c 2> "$d/peer.log" \
      || { cat "$d/peer.log" >&2; fail "abi386: gcc could not build peer.c at -mregparm=$rp"; }
    for fl in -O0 -Os; do
      moonrun -t i386 -mregparm=$rp $fl -c -o "$d/host$rp.o" test/cc/abi386/host.c > "$d/host.log" 2>&1 \
        || { cat "$d/host.log" >&2; fail "abi386: mooncc $fl could not build host.c at -mregparm=$rp"; }
      gcc -m32 -no-pie -o "$d/abi$rp" "$d/host$rp.o" "$d/peer$rp.o" 2> "$d/abi.log" \
        || { cat "$d/abi.log" >&2; fail "abi386: the link at -mregparm=$rp"; }
      "$d/abi$rp" > "$d/abi$rp.out" 2>&1 || { cat "$d/abi$rp.out" >&2; fail "abi386: mooncc $fl and gcc disagree at -mregparm=$rp"; }
    done
  done
  echo "abi386: $(tail -1 "$d/abi3.out") at each -mregparm, 0 to 3, ours plain and -Os"
  # skew386: over-aligned locals under -mstack-alignment=4 at each incoming esp, and at the ABI's plain
  for rp in 0 3; do
    gcc -m32 -mregparm=$rp -O1 -w -c -o "$d/skp$rp.o" test/cc/skew386/peer.c 2> "$d/skp.log" \
      || { cat "$d/skp.log" >&2; fail "skew386: gcc could not build peer.c at -mregparm=$rp"; }
    for sa in "-mstack-alignment=4" "-DSKEWS=1"; do
      for fl in -O0 -Os; do
        moonrun -t i386 -mregparm=$rp $sa $fl -c -o "$d/skh.o" test/cc/skew386/host.c > "$d/skh.log" 2>&1 \
          || { cat "$d/skh.log" >&2; fail "skew386: mooncc $sa $fl could not build host.c at -mregparm=$rp"; }
        gcc -m32 -no-pie -o "$d/skew" "$d/skh.o" "$d/skp$rp.o" 2> "$d/skl.log" \
          || { cat "$d/skl.log" >&2; fail "skew386: the link at -mregparm=$rp"; }
        "$d/skew" > "$d/skew.out" 2>&1 || { cat "$d/skew.out" >&2; fail "skew386: mooncc $sa $fl at -mregparm=$rp"; }
      done
    done
  done
  echo "skew386: $(tail -1 "$d/skew.out"), -mstack-alignment=4 and plain, -mregparm 0 and 3"
fi
if [ -n "$exitonly" ]; then
  # -ftrivial-auto-var-init=zero clears every word of a VLA and an alloca block
  cat > "$d/avz.c" <<'AVZ'
static void __attribute__((noinline)) dirty(void) { volatile char b[1024]; for (int i = 0; i < 1024; i++) b[i] = 255; }
static int __attribute__((noinline)) v(int n) { char a[n]; int s = 0; for (int i = 0; i < n; i++) s += a[i] != 0; return s; }
static int __attribute__((noinline)) h(int n) { char *a = __builtin_alloca(n); int s = 0; for (int i = 0; i < n; i++) s += a[i] != 0; return s; }
int cc_main(void) { dirty(); if (v(200)) return 1; dirty(); if (h(200)) return 2; return 0; }
AVZ
  moonrun -t "$tgt" -ftrivial-auto-var-init=zero -c -o "$d/avz.o" "$d/avz.c" > "$d/avz.log" 2>&1 \
    || { cat "$d/avz.log" >&2; fail "-ftrivial-auto-var-init=zero: mooncc could not build a VLA and an alloca"; }
  arm-none-eabi-ld -T "$d/link.ld" "$d/start.o" "$d/run.o" "$d/avz.o" "$lg" -o "$d/avz.elf" > "$d/avz.log" 2>&1 \
    || { cat "$d/avz.log" >&2; fail "-ftrivial-auto-var-init=zero: ld could not bind our object"; }
  timeout 60 qemu-system-arm -M $mach -semihosting -nographic -kernel "$d/avz.elf" < /dev/null > "$d/avz.out" 2>&1 \
    || fail "-ftrivial-auto-var-init=zero left a block uncleared on $mach"
fi

# does $1, ours under flag $2, answer as reference $3: its status in $4, its output in $5
same() {
  rg=$(cat "$4")
  [ "$rt" -eq "$rg" ] || { head -20 "$1" >&2; fail "$b: exit $rt ($2), $3 answers $rg"; }
  [ -n "$exitonly" ] || cmp -s "$5" "$1" || {
    echo "--- $b ($2): $3 vs ours on $pretty (first 20 differing lines) ---" >&2
    diff "$5" "$1" 2>/dev/null | head -20 >&2
    fail "$b: stdout ($2) differs from $3's"; }
}
n=0; ngcc=0
for b in $progs; do
  g=$r/res/$b.g; hasg=; [ -f "$g.rc" ] && hasg=1
  if [ -n "$hasg" ]; then
    [ "$(cat "$g.rc")" -ne 124 ] || fail "$b: $GCC's binary timed out -- the program, not us"
    ! grep -q "qemu: fatal" "$g.out" || fail "$b: $GCC's binary faulted on $mach -- the harness or the program, not our codegen"
  fi
  if inlist "$b" "$narrow"; then
    [ "$(cat "$g.rc")" -ne 0 ] || fail "$b: $GCC passes a program listed as narrow -- take it off the list"
  fi
  for os in t s; do
    fl=plain; [ $os = s ] && fl=-Os
    o=$r/res/$b.$os.out
    rt=$(cat "$r/res/$b.$os.rc" 2>/dev/null) || fail "$b: no answer from the $pretty batch"
    [ "$rt" -ne 124 ] || fail "$b: our binary ($fl) timed out $where"
    ! grep -q "qemu: fatal" "$o" || fail "$b: our binary ($fl) FAULTED ($(head -1 "$o"))"
    if inlist "$b" "$hosted $narrow"; then
      [ "$rt" -lt 128 ] || fail "$b: our binary ($fl) died on a signal ($rt)"
      continue
    fi
    [ -z "$x64ref" ] || same "$o" "$fl" "our x86-64" "$d/$b.xrc" "$d/$b.xout"
    [ -z "$hasg" ] || same "$o" "$fl" "$GCC" "$g.rc" "$g.out"
  done
  if inlist "$b" "$hosted"; then nhost=$((nhost + 1))
  elif inlist "$b" "$narrow"; then nnar=$((nnar + 1))
  else n=$((n + 1)); [ -z "$hasg" ] || ngcc=$((ngcc + 1)); fi
  # a passed case's files go (a static .g is ~3 MB); a failing one keeps them
  rm -f "${r:?}/${b:?}".* "${r:?}/res/${b:?}".* "${d:?}/${b:?}".*
done

[ $n -gt 0 ] || fail "no programs ran from test/cc/"
say="$name: $n programs answer $where, plain and -Os"
[ -z "$x64ref" ] || say="$say, as on x86-64"
[ -z "$GCC" ] || say="$say, $ngcc as $(basename "$GCC") does"
for c in "$nref refuse" "$nwide wide-refused-by-both" "$nnar narrow" "$nhost hosted" "$nlibc want-a-libc" "$nskip skipped"; do
  case $c in 0\ *) ;; *) say="$say, $c" ;; esac
done
echo "$say"
