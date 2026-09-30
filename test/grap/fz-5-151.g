.G1 4i 2i
coord x -2.93352, 891.425 y 10.2051, 227.315
grid left solid from 1 to 20 by 10
margin = 0.05
line dashed 0.05 from 623, 84.5 to 805.662, 65.6
for i from 1 to 4 by 2 do { plot bullet at i, i+1 }
copy thru { circle at $1, $2 } until "END"
726 87.5 x1
END
.G2
