; `love play src/apps/lore/levels/ring.l`: a world laid round a ring's tube, walked all the
; way round either way. x runs round the ring and z round the tube, its outside halfway; a
; row of posts down the outside, a ring of them round the tube, a stream crossing it, and a
; cairn where the walk begins, met again coming round
(borrow 'scenery)

(: lx 320.0 lz 112.0)

; the textures: grass, stone, the cairn's red stone and the stream
(: grass (feel 'soft (texture 64 64 2
          '((fill (rgb 0.3 0.52 0.2)) (noise 1 0.25) (noise 8 0.12) (patches 6 0.25 (shade 0.82))
            (patches 5 0.12 (rgb 0.5 0.66 0.26))))))
(: stone (feel 'hard (texture 32 32 1.2 '((fill (grey 0.55)) (noise 2 0.15) (patches 4 0.2 (shade 0.8))))))
(: red (feel 'hard (texture 32 32 1.2 '((fill (rgb 0.62 0.24 0.18)) (noise 2 0.15) (patches 4 0.2 (shade 0.8))))))
(: water (texture 64 64 4
          '((fill (rgb 0.16 0.36 0.5)) (noise 24 4 0.18) (patches 8 0.15 (rgb 0.4 0.6 0.72)) (noise 1 0.06))))

; the ground: swells that come round whole every way, and the stream's bed sunk across it
(: (ease v a b) (: k (min 1.0 (max 0.0 ((v - a) / (b - a)))) (k * k * (3.0 - 2.0 * k))))
(: (swell x z) (: a (tau * x / lx) b (tau * z / lz)
   (0.9 * (0.5 + 0.5 * sin (5.0 * a + 0.3)) * (0.5 + 0.5 * sin (3.0 * b + 1.1)) + 0.3 * sin (11.0 * a - 4.0 * b))))
(: stream 200.0)
(: (ground x z) (swell x z * ease (abs (x - stream)) 2.0 6.0 - 0.7 * (1.0 - ease (abs (x - stream)) 1.0 3.5)))
(: xs (map (i \ 2.0 * i) ^161) zs (map (i \ 2.0 * i) ^57))
(: (rows f) (map (z \ map (x \ [x (f x z) z]) xs) zs))

; a post standing on the ground at x z, a cairn three stones high
(: (post x z t) (: y (ground x z) (skin {'all t} (solid (box [(x - 0.2) (y - 0.5) (z - 0.2)] [(x + 0.2) (y + 1.8) (z + 0.2)])))))
(: (cairn x z) (: y (ground x z)
   (map (k \ (: a (0.9 - 0.25 * k) y0 (y - 0.4 + 0.6 * k) (skin {'all red} (solid (box [(x - a) y0 (z - a)] [(x + a) (y0 + 0.6) (z + a)])))))
        ^3)))

(level "the ring"
  (surface 'torus lx lz)
  (textures {'wall stone 'floor grass 'ceiling stone})
  (start [10 0 (lz / 2)] 90 0)
  (sky 13 'clear) (skylight (rgb 0.12 0.11 0.09))
  (ambient (rgb 0.32 0.32 0.3))
  (void [-4 -3 -4] [(lx + 4) 14 (lz + 4)])
  (land grass (rows ground))
  (flow [0.0 0.6] (drape water (map (z \ map (x \ [x -0.45 z]) [(stream - 2.6) stream (stream + 2.6)]) zs)))
  ; ..the cairn, the posts down the outside every sixteen metres, and round the tube every eight
  (cairn 6 (lz / 2))
  (map (x \ post x (lz / 2) stone) (filter (x \ abs (x - stream) > 4.0) (map (i \ 24.0 + 16.0 * i) ^18)))
  (map (i \ post 80.0 (4.0 + 8.0 * i) stone) ^14))
