; traybench.l -- the tray ops rove leans on, timed end to end: `love bench/traybench.l N`
; prints ms per op over N reps of a 4096-element tray (the shapes of bench/loops.c), best of three rounds
(: n 4096
   reps (argv @ a (two? >a ? (read <>a) 200))
   xs (iota n + 0.0)
   ys (iota n * 0.5 + 1.0)
   zs (iota n)
   ws (iota n * 3 % 11)
   idx (iota n * 37 % (n + 8))
   (ms f) (: t0 (nclock 0) _ (: (go k) (k < 1 ? 0 (f 0, go (k - 1))) (go reps))
             ((nclock 0 - t0 + 0.0) / reps / 1000000.0))
   ; the best of three rounds: the collector's phase moves a mean by a third on the allocating rows
   (row nm f) (: t (min (ms f) (min (ms f) (ms f))) (puts (nm + " " + show t + "\n")))
   (row "fadd" (_ \ xs + ys),
    row "fmul-scalar" (_ \ xs * 0.75),
    row "poly" (_ \ ((xs * 0.5 + 1.0) * xs - 0.25) * xs + 2.0),
    row "fmask" (_ \ xs < ys),
    row "fmin" (_ \ min xs ys),
    row "fsum" (_ \ net xs),
    row "iadd" (_ \ zs + ws),
    row "imax" (_ \ max zs ws),
    row "gather" (_ \ peep xs idx -1.0),
    row "floor" (_ \ floor ys),
    row "sin" (_ \ sin xs),
    row "bcast" (_ \ (iota 64 + 0.0) + (gem-tray [64 1] (map (x \ x + 0.0) ^64))),
    0))
