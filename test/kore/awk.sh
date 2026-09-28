#!/bin/sh
# test/kore/awk.sh -- awk against gawk
. "$(dirname "$0")/common.sh"

# gawk is the oracle and every check is byte-identical stdout. the input is a
# small table so fields, numbers and text all have something to bite on.
awkin=$ho/.kore-awkin
printf 'alice 30 engineer\nbob 25 baker\ncarol 41 engineer\n' > "$awkin"
aw() { n=$1; shift
       awk "$@" < "$awkin" > "$g" 2>/dev/null
       korerun awk "$@" < "$awkin" > "$o" 2>/dev/null
       same "awk $n"; }
aw fields   '{print $1, $3}'
aw nr-nf    '{print NR, NF, $NF}'
aw arith    'BEGIN{print 1+2, 7/2, 7%3, 2^10, -2^2, int(-3.7)}'
aw concat   'BEGIN{x="a"; y=1; print x y 2}'
aw numfmt   'BEGIN{print 1/3, 1e20, 0.00001, 100000, 3.0}'
aw strnum   '{if ($2 > 30) print $1}'
aw regex    '/engineer/{print $1}'
aw match    '{if ($0 ~ /^b/) print "b:" NR}'
aw rebuild  'BEGIN{OFS="-"}{$1=$1; print}'
aw setfield '{$2="X"; print}'
aw nf-set   '{NF=2; print; print NF}'
aw fs       -F' ' '{print NF}'
# -F and -v take their value through awk's own string escapes, so a BACKSLASH in one
# has to survive the walk. it used to reach a second aw-esc -- the SIGNAL escaper, a
# duplicate name later in the same letrec -- and every such run died `;; awk-exit ()`.
# -F'\t' is how the flag is nearly always written, and no check here ever held one.
awktab=$ho/.kore-awktab
printf 'a\tb\tc\nd\te\tf\n' > "$awktab"
for spelling in '-F\t' '-F	'; do
  awk "$spelling" '{print $2}' < "$awktab" > "$g" 2>/dev/null
  korerun awk "$spelling" '{print $2}' < "$awktab" > "$o" 2>/dev/null
  same "awk $spelling"
done
awk -F '\t' '{print NF}' < "$awktab" > "$g" 2>/dev/null
korerun awk -F '\t' '{print NF}' < "$awktab" > "$o" 2>/dev/null
same "awk -F spaced"
aw vesc     -v 'x=a\tb' 'BEGIN{print x}'
aw vplain   -v x=3 'BEGIN{print x+1}'
aw substr   'BEGIN{print substr("hello",2,3), substr("hello",0,3), substr("hello",4)}'
aw strfns   'BEGIN{print index("hello","ll"), length("hello"), toupper("aBc"), tolower("aBc")}'
aw split    'BEGIN{n=split("a:b:c",A,":"); print n, A[1], A[3]}'
aw gsub     '{n=gsub(/e/,"3"); print n, $0}'
aw subamp   'BEGIN{s="abc"; sub(/b/,"[&]",s); print s}'
aw matchfn  'BEGIN{print match("hello","l+"), RSTART, RLENGTH}'
aw printf   'BEGIN{printf "%s|%d|%5.2f|%-4s|%05d|%+d|%e|%g|%c|%x\n","a",42,3.14159,"b",42,7,1234.5,0.0000123,65,255}'
aw bignum   'BEGIN{print 1e20, 1e23, 2^60; printf "%d|%.0f\n", 1e20, 1e20}'
aw math     'BEGIN{printf "%.6f %.6f %.6f %.6f %.6f\n", atan2(1,1), atan2(1,-1), sin(1), cos(1), exp(2)}'
aw arrays   'BEGIN{a["x"]=1; a["y"]=2; n=0; for(k in a) n++; print n, ("x" in a), ("z" in a)}'
aw delete   'BEGIN{a[1]=1;a[2]=2; delete a[1]; print (1 in a), (2 in a), length(a)}'
aw subsep   'BEGIN{a[1,2]=5; print ((1,2) in a), ((1,3) in a)}'
aw loops    'BEGIN{for(i=0;i<6;i++){if(i==2)continue; if(i==4)break; printf "%d",i}; print ""}'
aw doloop   'BEGIN{i=0; do{printf "%d",i;i++}while(i<3); print ""}'
aw func     'function f(a,b){return a+b} BEGIN{print f(2,3)}'
aw funcarr  'function g(arr){arr["k"]=9} BEGIN{g(A); print A["k"]}'
aw funcloc  'function h(n,  i,s){for(i=1;i<=n;i++)s=s i; return s} BEGIN{print h(4)}'
aw recurse  'function fac(n){return n<=1?1:n*fac(n-1)} BEGIN{print fac(6)}'
aw next     '{if(NR==1) next; print "kept", $1}'
aw range    '/alice/,/bob/{print "R:" NR}'
aw uninit   'BEGIN{print x+0, "["x"]", length(x), !x}'
aw ofmt     'BEGIN{OFMT="%.2f"; print 3.14159, 3}'
aw convfmt  'BEGIN{CONVFMT="%.2g"; x=3.14159; print (x "")}'
aw vflag    -v x=7 'BEGIN{print x, x+1}'
aw dynre    'BEGIN{r="^b"; if("bob" ~ r) print "dyn-ok"}'
aw endonly  'END{print NR, $0}'
# the exit code is awk's own, and exit outside END still runs the END rules
korerun awk '{exit 3} END{print "end ran"}' < "$awkin" > "$o" 2>/dev/null; r=$?
[ $r -eq 3 ] && [ "$(cat "$o")" = "end ran" ] || fail "kore awk exit (exit $r): $(cat "$o")"
# a bad program is a diagnosed refusal, not a crash and not silence
korerun awk 'BEGIN{' < /dev/null > "$o" 2>"$g"; r=$?
[ $r -eq 2 ] && [ -s "$g" ] || fail "kore awk syntax error (exit $r)"
# -f takes the program off a file, and several concatenate
printf 'BEGIN{x=1}\n' > "$ho/.kore-awk1"; printf 'BEGIN{print x+1}\n' > "$ho/.kore-awk2"
awk -f "$ho/.kore-awk1" -f "$ho/.kore-awk2" < "$awkin" > "$g" 2>/dev/null
korerun awk -f "$ho/.kore-awk1" -f "$ho/.kore-awk2" < "$awkin" > "$o" 2>/dev/null
same "awk -f"
# case by character: gawk's answers under a utf-8 locale, spelled out so the gate's own
# locale cannot move them; a byte no character wears goes through as is
ac() { want=$1; got=$(printf '%s\n' "$2" | korerun awk "{print $3}")
       [ "$got" = "$want" ] || fail "kore awk $3 on $2: got [$got] want [$want]"; }
ac 'ÉAßÉ日X ǄSIİ ΣΣΣΩ' 'éaßÉ日x ǅſıİ ΣσςΩ' 'toupper($0)'
ac 'éaßé日x ǆſıi σσςω' 'éaßÉ日x ǅſıİ ΣσςΩ' 'tolower($0)'
echo "kore: awk (41 checks byte-identical to gawk, the exit code, -f, the refusal) ok"
