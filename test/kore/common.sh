# test/kore/common.sh -- the helpers every test/kore subject dots; never run alone.
# each subject takes OUTDIR LOVE. a check runs the system tool and ours alike and wants the
# same stdout, and the status where it carries meaning; gnu is independent, not right.
# not set -e: the status comparisons need $?
set -u

ho=$1
m=$2

fail() { echo "FAIL $*" >&2; exit 1; }
korerun() { LOVE_NO_IMAGE= "$m" kore "$@"; }
moonc() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }
# $ho and $m are relative, so checks that cd use these; a relative `<` inside a cd'd
# subshell hands an empty stdin, and both sides match doing nothing
case $ho in /*) HO=$ho;; *) HO=$PWD/$ho;; esac
K=$PWD/$m

g=$ho/.kore-g
o=$ho/.kore-o
same() { cmp -s "$g" "$o" || fail "kore $1 vs GNU"; }
# the workhorse: the system tool, then ours, then compare stdout
both() { n=$1; shift; "$@" > "$g" 2>/dev/null; korerun "$@" > "$o" 2>/dev/null; same "$n"; }
# ..and the status too; -C DIR runs both sides there
bothrc() { _c=.; [ "$1" = -C ] && { _c=$2; shift 2; }; n=$1; shift
           (cd "$_c" && "$@") > "$g" 2>/dev/null; rg=$?
           (cd "$_c" && LOVE_NO_IMAGE= "$K" kore "$@") > "$o" 2>/dev/null; ro=$?
           cmp -s "$g" "$o" && [ $rg -eq $ro ] || fail "kore $n vs GNU (exit $ro, GNU's $rg)"; }
# ..and the stdin face
pipe() { n=$1; i=$2; shift 2
         printf '%s' "$i" | "$@" > "$g" 2>/dev/null
         printf '%s' "$i" | korerun "$@" > "$o" 2>/dev/null
         same "$n"; }
# a door check: exit 0 and a first line matching
hv() { n=$1; want=$2; shift 2
       "$@" > "$o" 2>/dev/null; r=$?
       [ $r -eq 0 ] || fail "$n (exit $r)"
       grep -q "$want" "$o" || fail "$n: no \"$want\", got \"$(head -1 "$o")\""; }
