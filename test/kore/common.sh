# test/kore/common.sh -- what every check in test/kore/ drinks from. dotted, never run:
# each subject script takes OUTDIR and LOVE and dots this to get the helpers.
#
# The shape almost every check takes: run the system tool, run OUR applet the same way,
# and require byte-identical stdout -- and, where the exit code carries meaning (grep's
# 0/1/2, sed's 1/2, xargs' 123/127, expr's 0/1/2, patch's 0/1), that too. GNU is not
# assumed correct, only independent. That shape is `both`/`pipe`; where a check is
# genuinely its own thing it is written out in the subject's own file.
#
# NOT set -e: the exit-code comparisons need $? to survive.
set -u

ho=$1
m=$2

fail() { echo "FAIL $*" >&2; exit 1; }
korerun() { LOVE_NO_IMAGE= "$m" kore "$@"; }
moonc() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }
# the love and the out dir, spelled ABSOLUTELY: $m and $ho are relative (the root
# Makefile sets R := .), and the checks that cd somewhere -- split's output directory,
# patch's tree -- cannot use either. a `< $ho/p.diff` INSIDE a cd'd subshell opens
# after the cd, so a relative one silently hands patch an empty stdin -- and both sides
# then do nothing and match, which reads exactly like a pass.
case $ho in /*) HO=$ho;; *) HO=$PWD/$ho;; esac
K=$PWD/$m

g=$ho/.kore-g
o=$ho/.kore-o
same() { cmp -s "$g" "$o" || fail "kore $1 vs GNU"; }
# the workhorse: the system tool, then ours, then compare stdout
both() { n=$1; shift; "$@" > "$g" 2>/dev/null; korerun "$@" > "$o" 2>/dev/null; same "$n"; }
# ..and the stdin face
pipe() { n=$1; i=$2; shift 2
         printf '%s' "$i" | "$@" > "$g" 2>/dev/null
         printf '%s' "$i" | korerun "$@" > "$o" 2>/dev/null
         same "$n"; }
# a door check: run it, require exit 0 and a first line matching. the exit code is the
# half that is easy to lose -- a help leaving 2 reads as a usage error to its caller.
hv() { n=$1; want=$2; shift 2
       "$@" > "$o" 2>/dev/null; r=$?
       [ $r -eq 0 ] || fail "$n (exit $r)"
       grep -q "$want" "$o" || fail "$n: no \"$want\", got \"$(head -1 "$o")\""; }
