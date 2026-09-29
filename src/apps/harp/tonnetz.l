; src/apps/harp/tonnetz.l -- walking the just lattice by chords and by lines.
;
; the lattice's 3-5 plane is the tonnetz: a major triad is a triangle [root, +third,
; +fifth], a minor one the triangle pointing the other way, and three flips move a
; triad to a neighbour sharing two of its notes -- P (parallel, c major <-> c minor),
; R (relative, c major <-> a minor), L (leading tone, c major <-> e minor). in equal
; temperament some cycles of flips close; here they do not, and each misses by a comma.
;
; a line walks the lattice note to note, each step a small interval, and every note
; is voiced in the octave nearest the one before, so the contour stays smooth.

(module '(tonnetz
  triad ttones tflip twalk tchord tvoice common lpath pinv ptrans otonal utonal)
(borrow (: m (cite 'just) (? m m "src/apps/harp/just.l")))
(:
   ; a triad is [root-point kind], kind 'maj or 'min
   (triad p k) [p k]
   (ttones t) (: p (t 0)
                 (t 1 = 'maj ? [p (vadd p [0 1 0]) (vadd p [1 0 0])]
                               [p (vadd p [1 -1 0]) (vadd p [1 0 0])]))
   (tflip t f)
    (: p (t 0) mj (t 1 = 'maj)
       (? (f = 'P) [p (mj ? 'min 'maj)]
          (f = 'R) (mj ? [(vadd p [-1 1 0]) 'min] [(vadd p [1 -1 0]) 'maj])
          (f = 'L) (mj ? [(vadd p [0 1 0]) 'min] [(vadd p [0 -1 0]) 'maj])
          t))
   ; the triads a string of flips passes through, the start included
   (twalk t fs) (t . (? !(two? fs) () (twalk (tflip t <fs) >fs)))

   ; a pitch in the octave nearest a reference pitch (both ratios)
   (nearto ref r) (: o (oct r) c (cents (o * rinv ref))
                     k (floor (c / 1200.0 + 0.5))
                     (k > 0 ? (o * (1 /// ipow 2 k)) (o * ipow 2 (0 - k))))
   (ipow b e) (e < 1 ? 1 (b * ipow b (e - 1)))
   ; a chord's points as ratios, each note in the octave nearest the reference
   (tvoice ref ps) (map (p \ nearto ref (unpoint p)) ps)
   ; a walk of triads as chords, each voiced around the last one's middle
   (tchord ts ref)
    (? !(two? ts) ()
       (: c (sort (tvoice ref (ttones <ts)))
          (c . tchord >ts (c 1))))

   ; how many lattice points two chords share: what makes a move sound connected
   (common a b) #(filter (p \ elem p b) a)

   ; a line: start at 1 and take each step (a lattice vector), every note voiced
   ; next to the last
   (lpath steps)
    (: (go p r ss) (? !(two? ss) [r]
                      (: q (vadd p <ss) s (nearto r (unpoint q)) (r . go q s >ss)))
       (go [0 0 0] 1 steps))

   ; a phrase turned over: every ratio inverted, the utonal mirror of an otonal
   ; phrase, so its pull points the other way
   (pinv rs) (map (r \ (coin? r || !(two? r)) ? (rinv r) (pinv r)) rs)
   (ptrans k rs) (map (r \ (coin? r || !(two? r)) ? (k * r) (ptrans k r)) rs)
   ; the harmonic series' chords and their mirrors: 4:5:6:7 and 1/4:1/5:1/6:1/7
   (otonal ns) (: b <ns (map (n \ n /// b) ns))
   (utonal ns) (: t (last ns) (map (n \ t /// n) ns)))
) ; module tonnetz
