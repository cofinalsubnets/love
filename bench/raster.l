; facets alone, the frame lore's stones draws: a few thousand triangles through a perspective
; eye, some off the screen and some through the near plane, half of them textured. prints the
; frames' sum and ms a frame; RASTER_REPS frames (5 when unset)
(: fb-n 4000 fb-w 320 fb-h 708
   fb-r (getenv "RASTER_REPS" @ s (string? s ? (read s) 5))
   (fb-lcg s) ((s * 1103515245 + 12345) % 2147483648)
   ; n numbers in [0, 1), from a seed
   (fb-rs n s) (: (go i s acc) (i < n ? (fb-lcg s @ t (go (i + 1) t ((t / 2147483648.0) . acc))) acc) (go 0 s ()))
   fb-u (fb-rs (fb-n * 9) 7)
   (fb-at i) (fb-u i)
   ; a vertex: x y z, u v, r g b
   (fb-vx i k) (: z (0.0 - (0.3 + 30.0 * fb-at (9 * i + 2)))
                  [((fb-at (9 * i) * 2.4 - 1.2) * (0.0 - z) + 0.4 * k) ((fb-at (9 * i + 1) * 2.4 - 1.2) * (0.0 - z) + 0.4 * (k % 2)) (z - 0.2 * k)
                   (8.0 * k) (8.0 * (k % 2)) (fb-at (9 * i + 3)) (fb-at (9 * i + 4)) (fb-at (9 * i + 5))])
   fb-vs (gem-tray [(fb-n * 3 * 8)] (foldr (+) () (map (i \ fb-vx i 0 + fb-vx i 1 + fb-vx i 2) ^fb-n)))
   fb-ts (star-tray [(fb-n * 4)] (foldr (+) () (map (i \ [(3 * i) (3 * i + 1) (3 * i + 2) (i % 2 ? 0 -1)]) ^fb-n)))
   fb-tex (star-tray [64 64] (map (k \ (k * 2654435761) % 16777216) ^4096))
   fb-pm (gem-tray [16] [1.0 0.0 0.0 0.0 0.0 0.45 0.0 0.0 0.0 0.0 -1.002 -0.2002 0.0 0.0 -1.0 0.0])
   (fb-one _) (facets fb-w fb-h 0 fb-pm fb-vs fb-ts [[fb-tex]] ())
   t0 (clock 0)
   f (foldl (\ _ _ (fb-one 0)) () ^fb-r)
   ms (fb-r = 0 ? 0 ((clock 0 - t0) // fb-r))
   (putx ['sum (net f) 'ms ms]))
