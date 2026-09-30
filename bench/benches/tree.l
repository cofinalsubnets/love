; binary-trees allocation/GC stress: build a perfect binary tree of depth D (leaves nil), then count
; its nodes. checksum = 2^D-1.
(: (mk d) (d < 1 ? 0 (mk (d - 1) . mk (d - 1)))
   (ck t) (two? t ? (1 + (ck <t + ck >t)) 0)
 (bench "tree" (_ \ ck (mk 16))))
