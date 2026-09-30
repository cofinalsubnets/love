.G1 4i 2i
frame right dashed 0.1 left dashed
ticks left off
plot "a" ljust at 14.69, 86.5091
label right "\fBbold\fP" "10%" left .2
plot 1000 / 100 - max(48, 2) * (-20) at 94, 73.0
for i from 1 to 3 by *2 do { plot "i" at i, i*i }
arrow from 1, 1.1 to 74, 45.2
grid right solid from 1 to 6 by 2
line invis from 28.672, 84.9 to 61, 76.8312
.G2
