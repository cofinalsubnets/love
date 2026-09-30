.G1
for i from 1 to 4 by *2 do { plot bullet at i, i+1 }
frame top dotted
ticks top out .2 from 5 to 16
margin = .2
.sp
59.9228 68.0
56.71 42.1
82.0852 30.3
frame ht 1 wid 3.5 right solid
frame wid 2
label  "Time (s)" down 0.1
ticks top in 0.05 from 2 to 28 by 0.5 "%3.0f"
plot sprintf("%e", -3) at 49, 39.1
line dotted 0.05 from 47.0972, 44.5424 to 18.5296, 41.1094
.G2
