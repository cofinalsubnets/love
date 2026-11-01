.G1
ticks off
v = 3
plot "v" at v,v*2/3
plot "w" at 2^3, sqrt(4)+log(100)-exp(1)
plot sprintf("%g:%5.2f", v, v/7) at 1,1
print v
print "hi"
for i from 1 to 3 do { plot "i" at i, i }
for j = 1 to 10 by *2 do % plot "j" at j,0 %
if v > 2 then { plot "big" at 0,0 } else { plot "small" at 0,0 }
if v < 2 then { plot "big" at 0,0 } else { plot "small" at 0,0 }
.G2
