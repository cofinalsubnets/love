; test/uuzx.l -- what LZMA's obligations (test/uuzxvc.l) lean on that inflate's and bzip2's lemmas do not say.
(test
 ; under 4096, so under any width past 32
 (defq lz-fit (pi x nat nn nat w nat gw (inf-le 32 w) g (inf-lt x nn) h (inf-le nn 4096) (inf-lt x (inf-pow w)))
  (lam x nn w gw g h (inf-lttrans x nn (inf-pow w) g (inf-ltle nn (inf-pow w) (inf-lelt nn 4096 (inf-pow w) h (bz-w4k w gw))))))
 ; a tree's index: its base under bb, the counter under tp, both under nn
 (defq lz-ix (pi m nat tp nat b nat bb nat nn nat g (inf-lt m tp) h (inf-le b bb) e (inf-le (add bb tp) nn) (inf-lt (add b m) nn))
  (lam m tp b bb nn g h e (inf-lttrans (add b m) (add b tp) nn (inf-ltaddl b m tp g) (inf-letrans (add b tp) (add bb tp) nn (inf-addr b bb tp h) e))))
 ; a tree's step, m << 1 | b: under twice the top, at least 1, and the room left falls
 (defq lz-dbl (pi m nat tp nat g (inf-lt m tp) (inf-lt (add m m) (add tp tp)))
  (lam m tp g (inf-lttrans (add m m) (add m tp) (add tp tp) (inf-ltaddl m m tp g) (inf-addr m tp tp (inf-ltle m tp g)))))
 (defq lz-or (pi m nat tp nat b nat g (inf-lt m tp) h (inf-lt b 2) (inf-lt (add (add m m) b) (add tp tp)))
  (lam m tp b g h (inf-lttrans (add (add m m) b) (add (add m m) 2) (add tp tp) (inf-ltaddl (add m m) b 2 h)
   (inf-letr (add (add m 1) (add m 1)) (add (add m m) 2) (add tp tp) (inf-two m) (inf-dbl (add m 1) tp (inf-lt1 m tp g))))))
 (defq lz-ge1 (pi m nat b nat g (inf-le 1 m) (inf-le 1 (add (add m m) b)))
  (lam m b g (inf-letrans 1 m (add (add m m) b) g (inf-letrans m (add m m) (add (add m m) b) (inf-leaddr m m) (inf-leaddr (add m m) b)))))
 (defq lz-fall (pi m nat tp nat b nat g (inf-le 1 m) h (inf-lt m tp) (inf-lt (natminus tp (add (add m m) b)) (natminus tp m)))
  (lam m tp b g h (inf-lttr (natminus tp (add m (add m b))) (natminus tp (add (add m m) b)) (natminus tp m)
   (maponpaths nat nat (lam z (natminus tp z)) (add m (add m b)) (add (add m m) b) (inf-addassoc m m b))
   (inf-subby m tp (add m b) h (inf-le1 (add m b) (inf-letrans 1 m (add m b) g (inf-leaddr m b)))))))
 ; a tree's leaf: m - top, under top
 (defq lz-tres (pi m nat tp nat g (inf-lt m (add tp tp)) h (inf-le tp m) (inf-lt (natminus m tp) tp))
  (lam m tp g h (inf-subltr m tp tp h g)))
 ; the coders' indices off the state and the position
 (defq lz-by8 (pi p nat o nat g (inf-le p 15) (inf-le (add (inf-by8 p) o) (add 120 o)))
  (lam p o g (inf-addr (inf-by8 p) 120 o (inf-by8mono p 15 g))))
 (defq lz-sx (pi s nat p nat g (inf-le s 11) h (inf-le p 15) (inf-le (add (inf-by16 s) p) 191))
  (lam s p g h (inf-add2 (inf-by16 s) 176 p 15 (inf-by16mono s 11 g) h)))
 ; the literals' table, from its base: 768 below its length
 (defq lz-sub768 (pi n nat g (inf-le 768 n) (inf-le (add (natminus n 768) 256) n))
  (lam n g (inf-letrans (add (natminus n 768) 256) (add (natminus n 768) 768) n (inf-addl (natminus n 768) 256 768 (idpath false))
   (inf-subfit n 768 g))))
 ; a copy's room: on + len <= top <= cap
 (defq lz-room (pi on nat len nat tp nat cap nat g (inf-le len (natminus tp on)) h (inf-le on tp) k (inf-le tp cap) (inf-le (add on len) cap))
  (lam on len tp cap g h k (inf-letrans (add on len) tp cap (bz-nbr on len tp g h) k)))
 (defq lz-w8 (pi on nat ck nat len nat cap nat g (inf-lt ck len) h (inf-le (add len 8) (natminus cap on)) k (inf-le on cap)
                 (inf-le (add (add on ck) 8) cap))
  (lam on ck len cap g h k (inf-letrans (add (add on ck) 8) (add (add on len) 8) cap (inf-addr (add on ck) (add on len) 8 (inf-addl on ck len (inf-ltle ck len g)))
   (inf-letr (add on (add len 8)) (add (add on len) 8) cap (inf-addassoc on len 8) (bz-nbr on (add len 8) cap h k)))))
 (defq lz-cw (pi w nat cap nat g (inf-lt (add cap 8) (inf-pow w)) (inf-lt cap (inf-pow w)))
  (lam w cap g (inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) g)))
)
