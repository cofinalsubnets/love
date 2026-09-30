.G1 2i 1i
coord temp x 0,100 y 32,212
coord x 1,5 y 0,1
ticks left in from temp 32 to 212 by 60
ticks right
plot "a" at temp 50,100
plot "b" at 3,0.5
line from temp 0,32 to temp 100,212
.G2
text
.G1
graph A
frame ht 1 wid 1
1 1
2 2
graph B with .sw at A.se + (0.5,0)
frame ht 1 wid 1
3 3
4 5
.G2
