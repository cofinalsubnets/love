.G1
frame invis
define pt % plot "$1" at $2, $3 %
pt(a, 1, 2)
pt(b,2,3)
define sq { $1 * $1 }
plot "s" at sq(2), 3
copy thru % plot "$3" at $1,$2 %
1 1 one
2 4 two
3 9 three
.G2
.G1
frame solid ht 1.5 wid 2.5
copy thru { circle at $1,$2 } until "END"
1 2
2 3
END
3 3
margin = 0.2
.G2
