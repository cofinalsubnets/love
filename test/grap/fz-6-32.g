.G1 4i 2i
v2 = max(log(164.0), 10)
plot "v" at v2, 2
frame left invis .2 top dotted 0.05
plot "n" at 80.62, 16.8
frame ht 1.5 right invis left solid 0.05
draw
plot "Time (s)" ljust at 99, 41.9
new invis .2 "x"
for i from 1 to 6 do { plot "i" at i, i*i }
.G2
