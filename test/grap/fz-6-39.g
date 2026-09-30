.G1
plot "y" at 1, 46.6
define pt1 { plot "$1" at $2, $3 }
pt1(a, -4.12, 86.5001)
define pt2 { plot "$1" at $2, $3 }
pt2(xy, 87.845, 14.3)
plot "\fBbold\fP" at 97, 84.2565
frame ht 3
label right "\fBbold\fP" "x axis" above left .2
ticks left off
for i from 1 to 5 do { plot "i" at i, i*i }
coord aa x 4, 18 y -5, 30
grid top at aa 7
.G2
