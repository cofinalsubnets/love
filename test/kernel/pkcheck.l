(borrow 'harp)
(borrow 'play)
; the pack equivalence law, asked ON THIS SEAT. test/law/harp.l asks it hosted; pinv is C
; over a cask and a tray, and neither the truncation nor the byte order is a given on a
; machine whose float-to-int is its own.
(: lay (cite 'guts 'pinv)
   n 600
   ix ((iota n) * 1.0)
   L (((ix / (n * 1.0)) * 5.0) - 2.5)
   R (sin (ix * 0.017))
   (slowpack lr m g)
    (: SL <lr  SR >lr  c (cask (m * 4))
       (clip1 x) (: v (int (x * g))
                    (? (v > 32767) 32767 (v < -32768) -32768 (v & 65535)))
       (go i) (? (i >= m) c
                 (: l (clip1 (peep SL i 0))  r (clip1 (peep SR i 0))  o (i * 4)
                    _ (pin c o (l & 255))         _ (pin c (o + 1) ((l >> 8) & 255))
                    _ (pin c (o + 2) (r & 255))   _ (pin c (o + 3) ((r >> 8) & 255))
                    (go (i + 1))))
       (string (go 0)))
   (same g) (pack (L . R) n g = slowpack (L . R) n g)
   _ (puts ("pinv here      " + show !(nil? lay) + "\n"))
   _ (puts ("gain 20000     " + show (same 20000.0) + "\n"))
   _ (puts ("gain 900000    " + show (same 900000.0) + "\n"))
   _ (puts ("gain 100       " + show (same 100.0) + "\n"))
   (puts ("bytes          " + show #(pack (L . R) n 20000.0) + " (want " + show (n * 4) + ")\n")))
