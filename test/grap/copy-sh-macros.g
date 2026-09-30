before
.G1
copy "d2.inc"
sh % echo hello %
1 1
.G2
.G1
define mk { plot "$1" at $2, $2 }
v = 7
.G2
.G1
mk(q, v)
for i = 1 to 3 do {
  for j = 1 to 2 do { plot "ij" at i, j }
}
if v == 7 then { if 1 then % plot "yes" at 0, 0 % }
.G2
after
