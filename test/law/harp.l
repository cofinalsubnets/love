; a pattern maps a span to events: each law asks a span and reads [wb we v] back;
; the part is checked where it is the point (onsets)
(borrow 'harp)
(borrow 'play)                                  ; the voices
(:
   (we x)   [(qnum (evwb x)) (qnum (evwe x)) (evv x)]
   (evs p a b) (map we (p (qi a) (qi b)))
   (ons p a b) (map we (filter onset? (p (qi a) (qi b))))
   (cnt p a b) #(p (qi a) (qi b))
   ; a query answers in emission order (a stack interleaves), so value laws sort first
   (vals p a b) (map (x \ evv x)
                     (sortby (u \ v \ (evwb u) < (evwb v))
                             (filter onset? (p (qi a) (qi b)))))

   ; --- cycle time ---
   _ (test ; exact, so a third of a cycle survives being multiplied back
             (((1 /// 3) * 3) = (1 /// 1))
             (((1 /// 3) + (1 /// 6)) = (1 /// 2))
             ; ordered by value, not shape: a structural read gets 1/3 vs 1/6 backwards
             ((1 /// 6) < (1 /// 3))  !((1 /// 3) < (1 /// 6))
             ((-1 /// 2) < (1 /// 3)) ((7 /// 2) < (5 /// 1))
             ; equality by value, which onset? rests on
             ((qi 1) = (1 /// 1))  ((qi 2) = (4 /// 2))  !((qi 1) = (qi 2))
             ; a rational does not meet a tray, so frames go through qnum
             !((iota 4) + (1 /// 3))
             ; qfl floors where // truncates: cycle -1/2 is in cycle -1
             (0  = qfl (1 /// 2))   (-1 = qfl (-1 /// 2))
             (-1 = qfl (-1 /// 1))  (-2 = qfl (-3 /// 2))
             (0.25 = qnum (1 /// 4)))

   ; --- the floor of the algebra ---
   _ (test ((evs (pure 'a) 0 1) = [[0 1 'a]])
             ((evs (pure 'a) 0 3) = [[0 1 'a] [1 2 'a] [2 3 'a]])
             ((evs hush 0 4) = ())
             ((evs (fastcat [(pure 'a) (pure 'b)]) 0 1) = [[0 0.5 'a] [0.5 1 'b]])
             ; slowcat: each member a cycle, advancing only on its turn
             ((evs (slowcat [(pure 'a) (pure 'b)]) 0 2) = [[0 1 'a] [1 2 'b]])
             ((evs (slowcat [(fastcat [(pure 'a) (pure 'b)]) (pure 'c)]) 0 4)
              = [[0 0.5 'a] [0.5 1 'b] [1 2 'c] [2 2.5 'a] [2.5 3 'b] [3 4 'c]])
             (3 = cnt (fast (qi 3) (pure 'a)) 0 1)
             (2 = cnt (stack [(pure 'a) (pure 'b)]) 0 1))

   ; fast and slow undo each other, and rev is its own inverse
   pp (fastcat [(pure 'a) (pure 'b) (pure 'c)])
   _ (test ((evs (fast (qi 3) (slow (qi 3) pp)) 0 2) = (evs pp 0 2))
             ((evs (rev (rev pp)) 0 2) = (evs pp 0 2))
             ((evs (late (1 /// 4) (early (1 /// 4) pp)) 0 2) = (evs pp 0 2))
             ((vals (rev pp) 0 1) = ['c 'b 'a])
             ; rev is per cycle
             ((vals (rev pp) 1 2) = ['c 'b 'a]))

   ; --- whole vs part: a two-cycle event is struck where it begins ---
   sl (slow (qi 2) (pure 'a))
   _ (test (1 = cnt sl 0 1)  (1 = cnt sl 1 2)
             (onset? (sl (qi 0) (qi 1) 0))  !(onset? (sl (qi 1) (qi 2) 0))
             ((ons sl 0 2) = [[0 2 'a]])
             (1 = cnt (pure 'a) 0 1))
   ; a query that starts mid-cycle cuts the part and never the whole
   hev  (pure 'a (1 /// 2) (qi 1))
   _ (test (1 = #hev)  !(onset? (hev 0))
             ((qnum (evwb (hev 0))) = 0)  ((qnum (evpb (hev 0))) = 0.5))

   ; --- weights, windows, euclid ---
   _ (test ((evs (timecat [((qi 3) . (pure 'a)) ((qi 1) . (pure 'b))]) 0 1)
              = [[0 0.75 'a] [0.75 1 'b]])
             ((evs (squeeze (1 /// 4) (1 /// 2) (pure 'a)) 0 1) = [[0.25 0.5 'a]])
             ((bjork 3 8) = [1 0 0 1 0 0 1 0])
             ((bjork 5 8) = [1 0 1 1 0 1 1 0])
             ((bjork 2 5) = [1 0 1 0 0])
             (3 = #(ons (euclid 3 8 (pure 'a)) 0 1))
             (5 = #(ons (euclid 5 8 (pure 'a)) 0 1)))

   ; --- the cycle-indexed transforms ---
   e2 (every 2 (fast (qi 2)) (pure 'a))
   _ (test (2 = cnt e2 0 1)  (1 = cnt e2 1 2)  (2 = cnt e2 2 3)
             ((vals (iter 4 pp) 0 1) = ['a 'b 'c])
             ((vals (iter 4 pp) 1 2) = ['b 'c 'a])
             ((vals (palin pp) 0 1) = ['a 'b 'c])
             ((vals (palin pp) 1 2) = ['c 'b 'a])
             (4 = #(ons (seg (qi 4) (pure 'a)) 0 1))
             ; off stacks a shifted copy on the plain one: three fragments, two struck
             (3 = cnt (off (1 /// 4) (q \ q) (pure 'a)) 0 1)
             (2 = #(ons (off (1 /// 4) (q \ q) (pure 'a)) 0 1)))

   ; --- chance is a place, not a moment: or a live loop stutters ---
   dg (degby 0.5 (fast (qi 16) (pure 'a)))
   _ (test ((evs dg 0 4) = (evs dg 0 4))
             (0 < #(evs dg 0 8))  (#(evs dg 0 8) < 128)
             ; and two `?`s in one sequence must not agree by construction
             ((#(evs (mini "a? b? c? d? e? f? g? h?") 0 8)) < 64))

   ; --- continuous: a real span answers one event spanning it, an empty one nothing ---
   _ (test
      (sine (qi 0) (qi 1) @ r
       (1 = #r && ((0 = qnum (evwb (r 0))) && (1 = qnum (evwe (r 0))))))
      (foldl (a \ p \ a && ((1 = #(p (qi 0) (qi 1))) && !(p (qi 1) (qi 1))))
             1 [sine cosine saw isaw tri square rand])
      (: (v1 p) (evv (p (qi 0) (qi 1) 0))
         (foldl (a \ p \ a && (v1 p @ x (0.0 <= x && x <= 1.0)))
                1 [sine cosine saw isaw tri square rand]))
      (evv (range 2.0 3.0 saw (qi 0) (qi 1) 0) @ x (2.0 <= x && x <= 3.0))
      ((evv (rand (qi 3) (qi 4) 0)) = (evv (rand (qi 3) (qi 4) 0))))

   ; --- controls: tablets that merge ---
   hv (hit (pure "bd") (qi 0) (qi 1))
   _ (test (tablet? (evv (hv 0)))  ("bd" = (peep (evv (hv 0)) 's ()))
             ; # takes structure from the left and the value from the right
             ((pset (hit (pure "bd")) (note (pure 7)) (qi 0) (qi 1) @ r
               [(peep (evv (r 0)) 's ()) (peep (evv (r 0)) 'note ())])
              = ["bd" 7])
             ; psets folds # from the left: the later word wins a key
             ((: r ((psets (hit (pure "bd")) (note (pure 7)) (gain (pure 0.5)) (note (pure 9))) (qi 0) (qi 1))
                 v (evv (r 0))
                 [(peep v 's ()) (peep v 'note ()) (peep v 'gain ())])
              = ["bd" 9 0.5])
             (: (flat q) (evv (q (qi 0) (qi 1) 0) @ v [(peep v 's ()) (peep v 'note ())])
                (flat (psets (hit (pure "bd")) (note (pure 7))) = flat (pset (hit (pure "bd")) (note (pure 7)))))
             (1 = #((psets (hit (pure "bd"))) (qi 0) (qi 1)))
             ((jux rev (hit (fastcat [(pure "bd") (pure "sn")])) (qi 0) (qi 1) @ r
               (sort (map (x \ peep (evv x) 'pan ()) r)))
              = [0.0 0.0 1.0 1.0]))

   ; --- a string is mini, a number pure, a time made exact ---
   _ (test ((map (x \ evv x) (stack ["bd sn"] (qi 0) (qi 1))) = ["bd" "sn"])
             ((map (x \ peep (evv x) 's ()) (hit "bd sn" (qi 0) (qi 1))) = ["bd" "sn"])
             ((peep (evv (note 7 (qi 0) (qi 1) 0)) 'note ()) = 7)
             ((peep (evv (gain 0.5 (qi 0) (qi 1) 0)) 'gain ()) = 0.5)
             ((evs (fast 2 (pure 'a)) 0 1) = (evs (fast (qi 2) (pure 'a)) 0 1))
             ((evs (fast 1.5 (pure 'a)) 0 2) = (evs (fast (3 /// 2) (pure 'a)) 0 2))
             ((evs (late 0.25 (pure 'a)) 0 1) = (evs (late (1 /// 4) (pure 'a)) 0 1))
             ((evs (slowcat ["a" "b"]) 1 2) = [[1 2 "b"]])
             ((evs (rev "a b") 0 1) = [[0.5 1 "a"] [0 0.5 "b"]])
             ((peep (evv (((psets "sqr" (note -10) (slide 24)) (qi 0) (qi 1)) 0)) 'slide ()) = 24)
             ((evs (timecat [(3 . "a") (1 . "b")]) 0 1) = [[0 0.75 "a"] [0.75 1 "b"]]))

   ; --- smooth: values drift linearly between onsets; a span samples its middle
   (sm p b e) (evv (smooth p b e 0))
   _ (test ((sm (mini "0 10") (qi 0) qhalf) = 5.0)
             ((sm (mini "0 10") qhalf (qi 1)) = 5.0)         ; on the way back to 0
             ((sm (mini "0 10") (qi 0) (1 /// 4)) = 2.5)
             ((sm (mini "0 10") (qi 1) (3 /// 2)) = 5.0)
             ((sm (pure 4) (qi 0) (qi 1)) = 4)
             ((sm (mini "bd sn") (qi 0) qhalf) = "bd")
             (1 = #(smooth (mini "0 10") (qi 0) (qi 1)))
             !(smooth (mini "0 10") (qi 1) (qi 1)))

   ; --- slide: the voice integrates a rising frequency; an octave over a second ends
   ; at 1/ln 2 of the held cycles
   _ (test ((peep (evv (slide (pure 3) (qi 0) (qi 1) 0)) 'slide ()) = 3)
             ((vphase 1.0 100.0 0.0) = 100.0)
             ((abs (vphase 1.0 100.0 0.6931471805599453 - 144.26950408889634)) < 0.0001)
             ((vphase 0.0 100.0 0.6931471805599453) = 0.0)
             (: ix (iota 200 + 10)
                (amp v) (mkvoice 10 v 1000 1 ix)
                a (amp {'s "sin" 'note 0})  b (amp {'s "sin" 'note 0 'slide 0})  c (amp {'s "sin" 'note 0 'slide 12})
                (aall (a = b) && !(aall (a = c)))))

   ; --- mini-notation ---
   (m s) (map (x \ [(qnum (evwb x)) (qnum (evwe x)) (evv x)])
              (filter onset? (mini s (qi 0) (qi 1))))
   _ (test ((m "bd sn")     = [[0 0.5 "bd"] [0.5 1 "sn"]])
             ((m "bd*2 sn")   = [[0 0.25 "bd"] [0.25 0.5 "bd"] [0.5 1 "sn"]])
             ((m "[bd bd] sn") = [[0 0.25 "bd"] [0.25 0.5 "bd"] [0.5 1 "sn"]])
             ((m "bd ~ sn ~") = [[0 0.25 "bd"] [0.5 0.75 "sn"]])
             ((m "bd@3 sn")   = [[0 0.75 "bd"] [0.75 1 "sn"]])
             ((m "bd _ sn")   = [[0 (2 / 3) "bd"] [(2 / 3) 1 "sn"]])
             ((m "bd!2 sn")   = [[0 (1 / 3) "bd"] [(1 / 3) (2 / 3) "bd"] [(2 / 3) 1 "sn"]])
             ((m "bd(3,8)")   = [[0 0.125 "bd"] [0.375 0.5 "bd"] [0.75 0.875 "bd"]])
             ((m "0 .5 -2")   = [[0 (1 / 3) 0] [(1 / 3) (2 / 3) 0.5] [(2 / 3) 1 -2]])
             ; < > is one member per cycle, not one slot
             ((map (x \ evv x) (filter onset? (mini "<bd sn>" (qi 1) (qi 2)))) = ["sn"])
             (6 = #(m "bd*2, hh*4"))
             (6 = #(m "[bd*2, hh*4]"))
             ; a sample index rides the value as a tablet
             ((: r (m "bd:3") v (<r 2) [(peep v 's ()) (peep v 'n ())]) = ["bd" 3])
             ; every step of a bad string is still a step: no hang, no scare
             (0 <= #(m "bd ] sn"))))

; --- the voices reach pcm (hosted only) ---
(: _ (!(hosted && files) ? 0
        (: _ (setenv "HORN" "none")
           p (hit (mini "bd*2 [~ sn]"))
           w "out/.harp.wav"
           spc 24000                                   ; rate 24000, cps 1: one cycle
           _ (harp-wav p 0 1 24000 1 0 20000.0 w)
           q (open w "r")
           s (hot? q ? (slurp q @ b (close q, b + "")) "")
           _ (test (("RIFF" = snip s 0 4)  ("WAVE" = snip s 8 12)
                      ("data" = snip s 36 40)
                      (#s = (44 + (spc * 4)))))
           ; pk: the left peak of n frames from a
           (pk a n) (: e (44 + ((a + n) * 4))
                       (go i m) (i >= e ? m
                                   (: v ((s i) + ((s (i + 1)) << 8))
                                      u (v > 32767 ? (65536 - v) v)
                                      (go (i + 4) (u > m ? u m))))
                       (go (44 + (a * 4)) 0))
           _ (test ((pk 0 2000) > 1000)                            ; kick
                     ((pk (spc // 4) 2000) > 1000)                   ; kick
                     ((pk ((spc * 3) // 4) 2000) > 1000)             ; snare
                     ; the `~` still rings with the kick, so the law is a ratio, not a floor
                     ((10 * (pk ((spc * 2) // 3) 2000)) < (pk ((spc * 3) // 4) 2000)))
           ; the timed sink keeps the clock: two cycles at cps 2 take about a second
           t0 (clock 0)
           _ (harp-horn p 0 2 24000 2 0 20000.0)
           dt (clock t0)
           ((test (dt >= 400) (dt < 8000)),
            setenv "HORN" ()))))

; --- pack: the pinv fast path and the byte loop answer the same bytes ---
(:
   lay (cite 'guts 'pinv)
   ; pack's own slow arm, transcribed
   (slowpack lr n g)
    (: L <lr  R >lr  c (cask (n * 4))
       (clip1 x) (int (x * g) @ v
                  (? (v > 32767) 32767 (v < -32768) -32768 (v & 65535)))
       (go i) (i >= n ? c
                 (: l (clip1 (peep L i 0))  r (clip1 (peep R i 0))  o (i * 4)
                    (pin c o (l & 255), pin c (o + 1) ((l >> 8) & 255),
                     pin c (o + 2) (r & 255), pin c (o + 3) ((r >> 8) & 255),
                     go (i + 1))))
       (string (go 0)))
   n 600
   ix ((iota n) * 1.0)
   ; a ramp past both rails and a sine within them
   L (((ix / (n * 1.0)) * 5.0) - 2.5)
   R (sin (ix * 0.017))
   ((test lay
          (pack (L . R) n 20000.0 = slowpack (L . R) n 20000.0)
          ((n * 4) = #(pack (L . R) n 20000.0))),
    ; a gain that rails almost everything, then one that rails nothing
    (test (pack (L . R) n 900000.0 = slowpack (L . R) n 900000.0)),
    (test (pack (L . R) n 100.0 = slowpack (L . R) n 100.0))))

; the sentinel the gate reads
(say out "test/law/harp: patterns, mini-notation, voices\n")
