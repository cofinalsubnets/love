; --- test/law/drift.l: the just lattice (src/apps/harp/just.l), the center that walks
; it (src/apps/harp/drift.l), and the tonnetz's chords and lines (src/apps/harp/tonnetz.l) ---
; ratios are exact, so the lattice laws are equalities; the walk is floats over
; integer points, so its laws are about which point it lands on and what it owes.
(borrow 'harp)
(borrow 'just)
(borrow 'drift)
(borrow 'tonnetz)
(:
   (dr-near a b) (abs (a - b) < 0.000001)
   (dr-rots l) (map (i \ drop i l + take i l) ^#l)
   (dr-pow r k) (k < 1 ? 1 (r * dr-pow r (k - 1)))
   (dr-all l) (? !(two? l) 1 (<l ? (dr-all >l) 0))
   ; --- the lattice ---------------------------------------------------------------
   _ (test ; a ratio is its prime exponents, and back
           ([-4 4 -1 0] = monzo (81 /// 80))
           ((81 /// 80) = unmonzo [-4 4 -1 0])
           ('over = monzo (11 /// 8))                 ; past 7 is off the lattice
           ([1 0 0] = point (3 /// 2))
           ([1 0 0] = point 3)                         ; octaves are not a direction
           ((15 /// 8) = unpoint [1 1 0])
           ((3 /// 2) = oct (3 /// 8))
           ((3 /// 4) = near (3 /// 2))                ; the octave nearest 1
           ((4 /// 3) = near (4 /// 3)))
   _ (test (dr-near 701.955000865 (cents (3 /// 2)))
           (dr-near 1200.0 (cents 2))
           (dr-near 21.506289597 (cents (jcomma 'syntonic)))
           (dr-near 23.460010384 (cents (jcomma 'pythagorean)))
           (dr-near (log 6 / log 2) (tenney (3 /// 2)))
           ; a fifth up and a fifth down are one distance with octaves free
           (lnorm [1 0 0] = lnorm [-1 0 0])
           ('fifth = jname 3)
           (() = jname (7 /// 5)))
   ; the paths that disagree: four fifths against a third and two octaves is the
   ; syntonic comma, and the fixed scale's d-a is that much short of a fifth
   _ (test ((dr-pow (3 /// 2) 4 * (1 /// 4) * (4 /// 5)) = jcomma 'syntonic)
           ((5 /// 3) * rinv (9 /// 8) = (40 /// 27))
           (dr-near (cents (40 /// 27)) (cents (3 /// 2) - cents (jcomma 'syntonic))))
   ; --- the euclidean bridge --------------------------------------------------------
   _ (test ; log2 3/2's convergents: the equal divisions with the best fifths
           ([12 41 53] = map (x \ x 1) (filter (x \ elem (x 1) [12 41 53])
                                              (convergents (cfrac (log 1.5 / log 2) 8))))
           (7 = <(edo-near 12 (3 /// 2)))
           (abs <>(edo-near 12 (3 /// 2)) < 2.0)
           (abs <>(edo-near 53 (3 /// 2)) < 0.1)
           ; seven fifths make the diatonic steps: 5 large, 2 small, a rotation of bjork 5 7
           (7 = #(mos (3 /// 2) 7))
           (5 = +(mos-steps (3 /// 2) 7))
           (elem (mos-steps (3 /// 2) 7) (dr-rots (bjork 5 7))))
   ; a triad is smoother than a cluster
   _ (test (pdiss [1 (5 /// 4) (3 /// 2)] < pdiss [1 (16 /// 15) (45 /// 32)])
           (0.0 = pdiss [1]))

   ; --- the walk --------------------------------------------------------------------
   maj [1 (5 /// 4) (3 /// 2)]
   _ (test ; a phrase at home pulls nowhere; a major one leans up the fifths and thirds
           (tension [1 2 4] = [0.0 0.0 0.0])
           (<(tension maj) > 0.0 && <>(tension maj) > 0.0)
           ; the kernel owes exactly what a step could not take
           (dr-near 1.0 (foldl (+) 0.0 dkernel)))
   wup (drift-walk {'lean 1.0} [maj] 8)
   wdn (drift-walk {'lean -1.0} [maj] 8)
   wz (drift-walk {'lean 0.0} [maj] 8)
   _ (test (8 = #wup)
           ([0 0 0] = (wup 0) 'pos)                     ; the first phrase plays at home
           ; lean follows the notes up the lattice, its negative leans away, zero stays
           (<((wup 7) 'pos) > 0)
           (<((wdn 7) 'pos) < 0)
           (dr-all (map (st \ st 'pos = [0 0 0]) wz))
           ; the center is the point's pitch, the octave nearest home
           (dr-all (map (st \ st 'tonic = near (unpoint (st 'pos))) wup))
           ; each step is one of the moves
           (dr-all (map (st \ elem (st 'move) dmoves) wup))
           ; and the walk mirrors: -lean lands on the negated points
           (map (st \ st 'pos) wdn = map (st \ vscale -1 (st 'pos)) wup))
   ; the owed error is what the kernel spread: its head plus the rest is want - move
   st1 (drift-step {} (drift-new {}) maj)
   _ (test (dr-near 0.0 (lnorm (vsub (foldl vadd [0.0 0.0 0.0] (st1 'queue))
                                     (vsub (st1 'want) (st1 'move))))))
   ; home pulls a travelling walk back toward the start
   far  (drift-walk {'lean 1.0} [maj] 16)
   held (drift-walk {'lean 1.0 'home 0.5} [maj] 16)
   _ (test (lnorm ((last held) 'pos) < lnorm ((last far) 'pos)))

   ; --- the tonnetz and the chooser ------------------------------------------------
   cmaj (triad [0 0 0] 'maj)
   _ (test ; a flip keeps two notes and undoes itself
           (dr-all (map (f \ 2 = common (ttones cmaj) (ttones (tflip cmaj f))) ['P 'R 'L]))
           (dr-all (map (f \ tflip (tflip cmaj f) f = cmaj) ['P 'R 'L]))
           ; the cycles that close in twelve do not here: PL thrice misses by the diesis,
           ; PR four times by four minor thirds against an octave
           ([[0 -3 0] 'maj] = last (twalk cmaj ['P 'L 'P 'L 'P 'L]))
           (dr-near (cents (jcomma 'diesis)) (1200.0 - cents (unpoint [0 3 0])))
           ([[4 -4 0] 'maj] = last (twalk cmaj ['P 'R 'P 'R 'P 'R 'P 'R]))
           ; a line round a parallelogram comes home
           (1 = last (lpath [[1 0 0] [0 1 0] [-1 0 0] [0 -1 0]]))
           ; a phrase turned over pulls the other way
           (tension (pinv maj) = vscale -1.0 (tension maj))
           ([1 (5 /// 4) (3 /// 2) (7 /// 4)] = otonal [4 5 6 7]))
   picks (map (x \ x 1) (drift-compose {'fresh 5.0} [maj (pinv maj)] 6))
   _ (test (6 = #picks)
           ; a dear repeat, so the chooser alternates
           (dr-all (map (i \ picks i != picks (i + 1)) ^5)))

   ; --- into harp -------------------------------------------------------------------
   song (drift-song {} [maj [[1 (5 /// 4) (3 /// 2)]]] 2)
   evs  (song (qi 0) (qi 2))
   (test (6 = #evs)                                    ; three in turn, then a chord of three
         (dr-near 0.0 ((evv <evs) 'note))
         (dr-near (semis (5 /// 4)) ((evv (evs 1)) 'note))
         (dr-near (semis (3 /// 2)) ((evv <((tune (3 /// 2) (pure 1)) (qi 0) (qi 1))) 'note))))

; the sentinel the gate reads
(say out "test/law/drift: the just lattice, the walk, the tuning\n")
