#!/bin/sh
# test/gate/asmops.sh -- the inline-asm SEAM gate.
#
# inle/<a>/asmops.h says every privileged instruction the kernel needs
# ONCE, in GNU's template: clang reads it natively, mooncc lowers the same text
# through core/holo/gas.l. one spelling, two readers -- and the reader that
# rots quietly is ours, so:
#
#   1. COVERAGE. every `static inline k_*` the header defines is called by
#      test/gate/asmops.c. derived from the header itself, so adding an op and
#      forgetting the probe fails here rather than going unchecked. ⚠ the probe
#      also takes each op's ADDRESS (k_asmops_keep): calling one is not enough
#      to make it EXIST, since a static inline whose calls are all inlined is
#      dead and a compiler is right to drop it.
#   2. MOONCC TAKES IT. the probe compiles with `mooncc -t <arch> -nostdinc`.
#      that alone exercises the whole seam: -nostdinc keeps glibc's headers out
#      of a freestanding compile, and each template goes through the GNU-dialect
#      front and holo's encoder (an unknown op or a bad operand SCARES, it does
#      not shrug).
#   3. THE TWO READERS AGREE. with clang present, compile the same probe with
#      it and compare the two objects op by op: same privileged mnemonics, same
#      symbolic operands, same order, inside the same function. this is rung 5's
#      compiler-vs-compiler differential in miniature, and it is the only check
#      that can catch our reading of a template drifting from GNU's.
#
# what the comparison deliberately does NOT compare: register allocation (the
# two compilers pick different ones and both are right) and the plain
# arithmetic around a privileged instruction. so a wrong MASK inside a
# read-modify-write is out of its reach -- those live in C-readable form in the
# header, and the encodings themselves are frozen in test/holo/golden.l.
#
# usage: asmops.sh HOSTDIR
set -u
ho=$1
probe=test/gate/asmops.c
work=${TMPDIR:-/tmp}/asmops.$$
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT
rc=0
fail() { echo "FAIL test_asmops: $*" >&2; rc=1; }
moonc() { LOVE_NO_IMAGE= "$ho/love" mooncc "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

# declared divergences, per arch: none. a name here is an op the two readers
# are allowed to disagree on, with its reason beside it.
divergent_x64=""
divergent_a64=""
divergent_rv64=""

# the privileged sequence of each function in an object: mnemonic and symbolic
# operands, registers normalized away. k_asmops_probe itself is skipped -- it is
# the inlined copy of everything below it, and the two compilers inline
# differently.
seq() {
  llvm-objdump -d --no-show-raw-insn "$1" | awk -v arch="$2" '
    /^[0-9a-f]+ <.*>:$/ { fn=$2; sub(/^</,"",fn); sub(/>:$/,"",fn)
                          if (fn == "k_asmops_probe") fn=""
                          if (fn != "") print "@" fn
                          next }
    fn == "" { next }
    {
      line=$0
      sub(/^[ \t]*[0-9a-f]+:[ \t]*/, "", line)
      sub(/[ \t]*(\/\/|#[ ]).*$/, "", line)        # objdump aside comments
      gsub(/[ \t]+/, " ", line); sub(/ +$/, "", line)
      if (line == "") next
      if (arch == "x64") {
        if (line !~ /^(cli|sti|hlt|ud2|int3|in[bwl]|out[bwl]|div[qlw])( |$)/ &&
            line !~ /^(rdmsr|wrmsr|cpuid|vmrun|vmload|vmsave|stgi|clgi)( |$)/ &&
            line !~ /^(vmxon|vmclear|vmptrld|vmxoff|vmlaunch)( |$)/ &&
            line !~ /^(vmread|vmwrite)q?( |$)/ &&
            line !~ /^(sgdt|sidt|lgdt|lidt)q?( |$)/ &&
            line !~ /%cr[0-9]/ && line !~ /^(and|or)[qlw]? \$/) next
        gsub(/%r[a-z0-9]+|%e[a-z]+|%[a-d][lh]/, "R", line)
      } else if (arch == "a64") {
        if (line !~ /^(isb|dsb|dmb|wfi|wfe|eret|mrs|msr|at|tlbi|ic|dc|brk|udf|hlt|hvc|smc)( |$)/) next
        gsub(/ [xw][0-9]+/, " R", line); gsub(/,[xw][0-9]+/, ",R", line)
      } else {
        if (line !~ /^(wfi|fence|ecall|ebreak|unimp|sfence\.vma|csr[a-z]*|rd(time|cycle|instret))( |$)/) next
        gsub(/ (a[0-7]|t[0-6]|s[0-9]+|ra|sp)/, " R", line); gsub(/,(a[0-7]|t[0-6]|s[0-9]+|ra|sp)/, ",R", line)
      }
      print "  " line
    }'
}

for a in x64 a64 rv64; do
  case $a in
    x64)  t=x64;  ctarget=x86_64-none-elf ;;
    a64)  t=a64;  ctarget=aarch64-none-elf ;;
    rv64) t=rv64; ctarget=riscv64-none-elf ;;
  esac
  h=inle/$a/asmops.h
  # -I inle is arch-neutral: inle/asmops.h picks by the target's own predefine
  inc="-I inle -I apps/moon/include"

  # 1. coverage, straight off the header
  for op in $(sed -n 's/^static inline [^(]* \**\(k_[A-Za-z0-9_]*\)(.*/\1/p' "$h"); do
    grep -q "$op(" "$probe" || fail "$a: $h defines $op, and $probe never calls it"
  done

  # 2. mooncc takes it
  if ! moonc -t $t -nostdinc -c $inc "$probe" -o "$work/$a-moon.o" 2>"$work/$a.err"; then
    fail "$a: mooncc could not compile the probe"; sed 's/^/    /' "$work/$a.err" >&2; continue
  fi

  if ! have llvm-objdump; then
    echo "  (asmops $a: sequence checks skipped, no llvm-objdump)"; continue
  fi
  seq "$work/$a-moon.o" $t > "$work/$a-moon.seq"
  # every op the object carries must have emitted at least one privileged
  # instruction -- a template that assembled to nothing is a silent no-op.
  # (a `for`, not a piped `while`: a fail inside a pipeline's subshell never
  # reaches rc, and the gate read green over a red.)
  empties=$(awk '/^@/ { if (name != "" && n == 0) print name; name=substr($0,2); n=0; next }
                 { n++ }
                 END { if (name != "" && n == 0) print name }' "$work/$a-moon.seq")
  for empty in $empties; do fail "$a: $empty emitted no privileged instruction"; done

  # 3. the two halves against each other
  if ! have clang; then
    echo "  (asmops $a: clang differential skipped, no clang)"; continue
  fi
  if ! clang -target $ctarget -ffreestanding -nostdinc -O0 -c $inc "$probe" \
             -o "$work/$a-clang.o" 2>"$work/$a.cerr"; then
    echo "  (asmops $a: clang differential skipped, no $ctarget support)"; continue
  fi
  seq "$work/$a-clang.o" $t > "$work/$a-clang.seq"
  eval "skip=\$divergent_$a"
  # ⚠ the two sides are separated by a MARKER LINE, not by which file a record came
  # from. An empty side is a real state -- a compiler that inlines every op and drops
  # the dead statics emits none of them -- and FNR==1 never fires for an empty file,
  # so a record-driven side counter silently files the OTHER compiler's functions under
  # the first one's name and blames the wrong half. That is exactly what it did.
  n=$({ cat "$work/$a-moon.seq"; echo "@@side@@"; cat "$work/$a-clang.seq"; } |
      awk -v skip="$skip" '
    function flush(  i) {
      if (name == "") return
      key = name; body = ""
      for (i = 1; i <= n; i++) body = body lines[i] "\n"
      if (side == 1) { A[key] = body; order[++k] = key }
      else { B[key] = body; orderB[++kb] = key }
      n = 0
    }
    BEGIN { side = 1 }
    /^@@side@@$/ { flush(); side = 2; name = ""; next }
    /^@/ { flush(); name = substr($0, 2); next }
    { lines[++n] = $0 }
    END {
      flush()
      bad = 0
      for (i = 1; i <= k; i++) {
        key = order[i]
        if (index(" " skip " ", " " key " ")) continue
        if (!(key in B)) { printf "%s: clang emitted no %s\n", key, key > "/dev/stderr"; bad++; continue }
        if (A[key] != B[key]) {
          printf "%s: the two halves of asmops.h disagree\n  mooncc:\n%s  clang:\n%s",
                 key, A[key], B[key] > "/dev/stderr"
          bad++
        }
      }
      # ..and the other direction, which used to be silence: an op only ONE compiler
      # emitted was simply never compared, so the gate could lose coverage and stay green.
      for (i = 1; i <= kb; i++) {
        key = orderB[i]
        if (index(" " skip " ", " " key " ")) continue
        if (!(key in A)) { printf "%s: mooncc emitted no %s\n", key, key > "/dev/stderr"; bad++ }
      }
      print bad
    }' 2>"$work/$a.diff")
  if [ "${n:-1}" != 0 ]; then
    sed 's/^/    /' "$work/$a.diff" >&2
    fail "$a: $n op(s) disagree between the mooncc and clang spellings"
  fi
done

[ $rc = 0 ] && echo "asmops: mooncc and clang read every template alike, on all three arches"
exit $rc
