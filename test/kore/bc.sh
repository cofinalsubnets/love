#!/bin/sh
# test/kore/bc.sh -- bc: the scale rules, the bases both ways, the language, the wrap, -l
. "$(dirname "$0")/common.sh"

# bc SAYS EVERYTHING ON STDOUT and complains only on stderr, so the printed run IS
# the check. every digit under it is exact (a number is an integer over a power of
# ten, in love's own bigints), which is why the math library can be asked for the
# same bytes GNU prints rather than for a tolerance.
# THE LIBRARY IS ASKED AT SCALE 10 AND UP. below that the two part company on 29
# of 735 sampled calls, every one of them a place where GNU's series has run out of
# guard digits and ours has not -- ours is the correctly truncated value each time
# (checked against GNU's own answer at scale 40), so agreeing there would be wrong.
bcp=$ho/.kore-bc.p
# NAME [FLAG..]: the program arrives on stdin, both bcs run it, stdout must match
bck() { n=$1; shift; cat > "$bcp"
        bc "$@" < "$bcp" > "$g" 2>/dev/null
        korerun bc "$@" < "$bcp" > "$o" 2>/dev/null
        same "$n"; }

bck "bc scale rules" <<'E'
1+1
2-5
3*4
2*3.25
1.5+1.5
scale=5
1/3
-1/3
17%5
10%3
scale=0
17%5
-17%5
17%-5
10/4
2^10
2.5^3
2^-2
0^0
2^0
0^3
-2^2
2^3^2
-3%2
scale=4
2^-2
sqrt(2)
sqrt(0)
sqrt(1)
sqrt(4)
sqrt(2.25)
scale=20
1/7
2/7
1/3*3
scale=12
1.000000000001*1.000000000001
-123456789.123456789/987654.321
E

bck "bc length and scale" <<'E'
length(0)
scale(0)
length(0.000)
length(.5)
length(-123)
length(123.456)
scale(123.456)
length(100)
scale(1/1)
scale=7
scale(1/3)
length(1/3)
E

bck "bc the bases" <<'E'
obase=16
255
-255
255.5
obase=2
10
scale=2
1/4
obase=8
scale=10
1/3
obase=20
scale=2
1/3
obase=17
scale=0
16
17
obase=100
0
5
99
100
-1234
scale=3
1234.5678
obase=1000
1234567
obase=10
ibase=2
101
3
12
9
ibase=16
FF
ibase=A
11
E

bck "bc the language" <<'E'
define f(x) { auto y; y = x*2; return(y) }
f(21)
define fb(x) { return x*2 }
fb(4)
define fn() { return }
fn()
print "a\zb\qc\n"
define fac(n) { if (n<=1) return(1); return(n*fac(n-1)) }
fac(30)
i=0
while (i<3) { print i, " "; i+=1 }
print "\n"
for (j=0;j<3;j++) { j }
for(i=0;i<5;i++){ if(i==2) continue; if(i==4) break; i }
1==1
2<1
1<2<3
!0
!5
1&&0
1||0
define sc1() { sg = 1; return (1) }
sg = 0
0 && sc1()
sg
1 || sc1()
sg
"hi"
last
.
i=5
i++
i
++i
i
i--
--i
i
x=10
x+=5
x
x*=2
x
x^=2
x
a[0]=1
a[5]=7
a[0]+a[5]
a[9]
define sum(v[], n) { auto i, t; for (i=0; i<n; i++) t += v[i]; return (t) }
for (i=0; i<10; i++) w[i] = i*i
sum(w[], 10)
w[3]
zz
zz+1
xyz = 5
xyz*2
if (1) 5 else 6
if (0) { 5 } else { 6 }
1;2;3
{4;5}
/* a comment */ 1+1 # and the other one
2 \
+ 3
scale=3
scale
scale+1
obase
ibase
2^2000
length(2^2000)
E

bck "bc the 68-column wrap" <<'E'
scale=200
1/3
scale=50
print 1/3, 1/3
print "\n"
print "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX", 1/3
print "\n"
obase=100
scale=40
1/3
E

bck "bc -l at scale 20" -l <<'E'
scale
s(1)
c(0)
c(1)
a(1)
l(2)
e(1)
e(-1)
e(100)
j(0,1)
j(1,1)
j(-1,.25)
s(0)
l(1)
a(0)
4*a(1)
s(a(1))
l(e(1))
E

bck "bc -l at scale 40" <<'E'
scale=40
s(.5)
c(.5)
a(.5)
e(.5)
l(.5)
s(-2)
c(-2)
a(10)
e(-10)
l(12345)
j(2,3)
j(-3,8)
E

# a runtime error costs its own statement and the source walks on -- and both bcs
# leave with 0 either way, which is GNU's reading and not POSIX's
# ... and a frame comes back even when the body it belongs to dies partway
printf 'x = 5\ndefine fd(x) { auto y; y = 3; return (1/0) }\ny = 99\nfd(9)\nx\ny\n' > "$bcp"
bc < "$bcp" > "$g" 2>/dev/null
korerun bc < "$bcp" > "$o" 2>/dev/null
same "bc frame after a death"
printf '1/0\n7\nsqrt(-1)\n8\n' > "$bcp"
bc < "$bcp" > "$g" 2>/dev/null; a=$?
korerun bc < "$bcp" > "$o" 2>/dev/null; b=$?
cmp -s "$g" "$o" && [ $a -eq $b ] || fail "kore bc after a runtime error (gnu $a ours $b)"
# the files come first and stdin after them, and a missing one only costs the status
printf 'x = 6\n' > "$ho/.kore-bc1"; printf 'y = 7\n' > "$ho/.kore-bc2"
printf 'x*y\n' | bc "$ho/.kore-bc1" "$ho/.kore-bc2" > "$g" 2>/dev/null
printf 'x*y\n' | korerun bc "$ho/.kore-bc1" "$ho/.kore-bc2" > "$o" 2>/dev/null
same "bc files then stdin"
printf '' | bc "$ho/.kore-bc-nope" > /dev/null 2>&1; a=$?
printf '' | korerun bc "$ho/.kore-bc-nope" > /dev/null 2>&1; b=$?
[ $a -eq $b ] || fail "kore bc missing file (gnu $a ours $b)"
# dc: GNU's, stdout and stderr, over the arithmetic and its scale, the bases, the
# registers and arrays, macros and their exits, and every complaint
# read(): the program from a file, its number from stdin's next line, in ibase (one read and one
# line: GNU's blocks on a second read, and its first swallows the rest of stdin)
printf 'ibase = 16; a = read()\na * 2\n' > "$ho/.kore-bc-rd"
for i in '1A\n' '-2.5\n' '0\n'; do
  pipe "bc read() of $i" "$(printf -- "$i")
" bc -q "$ho/.kore-bc-rd"
done
if command -v dc >/dev/null 2>&1; then
  cat > "$ho/.kore-dc.cases" <<'EOF'
2 3+p
5k1 3/p
_5 2/p
2 10^p
2 0.5^p
10k2vp
16o255p
16i FFp
2o10p
20o 1000000 p
[hello]p
256 65*66+P
1 2 3f
1 2 3 zp
3.14159 Xp
_12.340 Zp Xp
[abc]Zp
1 2r f
d
5 Sa 6 Sa La p La p
[2p]sa 1 1 =a
[2p]sa 1 2 >a
[1p]sa 1 2 !>a
3 [1-d0<a]sa lax f
1 2 3 4 R f
1 2 3 _3 R f
7 3 ~ f
2 10 7 |p
10 3 k /p K p
1 2 3 [q]x f
4 3 [2Q]x f
1 0/p
5 0%p
5 1:a 1;a p
99999999999999999999999999999999999999999999999999999999999999999999999999999999 p
_1k
17i
1o
[a]1+
_4v
3k 2 _2^p
0.5 2^p
65 a p
1 2 ]
e
EOF
  # a line at a time by number, not a while read: under lush dc is the in-image verb,
  # and a verb in a read loop drinks the loop's own buffered input before its pipe
  nc=$(wc -l < "$ho/.kore-dc.cases"); i=1
  while [ $i -le $nc ]; do
    p=$(sed -n "${i}p" "$ho/.kore-dc.cases"); i=$((i + 1))
    printf '%s\n' "$p" | dc > "$g" 2>&1; printf '%s\n' "$p" | korerun dc > "$o" 2>&1; same "dc [$p]"
  done
  printf '1 2+p\n' > "$ho/.kore-dc.f"
  dc -e '3 4*p' -f "$ho/.kore-dc.f" > "$g" 2>&1; korerun dc -e '3 4*p' -f "$ho/.kore-dc.f" > "$o" 2>&1; same "dc -e -f"
  printf '[2p\n3p]x\n' | dc > "$g"; printf '[2p\n3p]x\n' | korerun dc > "$o"; same "dc: a string over two lines"
fi
echo "kore: bc (the scale rules, the bases both ways, the language, the wrap, -l, GNU-identical) + dc ok"
