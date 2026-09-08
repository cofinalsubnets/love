; --- apps/harp/law.l: harp, tidal's cycle algebra in love (apps/harp/harp.l) ---
; the laws are queries: a pattern is a function from a span to events, so every
; combinator can be checked by asking it for a span and reading the answer. the
; shape under test is [wb we v] per event, with the times as plain numbers -- the
; part is checked separately, where it is the point (onsets, tails, `appl`).
;
; the voices (apps/harp/play.l) are checked at the far end only: one cycle out the
; timed sink keeps time, and one cycle into a .wav has the right header and puts
; its energy where the pattern said. no gate can listen.
(borrow 'harp)
(:
   ; an event, flattened for comparison: begin, end, value
   (we x)   [(qnum (evwb x)) (qnum (evwe x)) (evv x)]
   (evs p a b) (map we (p (qi a) (qi b)))
   (ons p a b) (map we (filter onset? (p (qi a) (qi b))))
   (cnt p a b) #(p (qi a) (qi b))
   ; a query answers in EMISSION order, not time order -- a stack interleaves its
   ; members -- so a law about which value lands where sorts first.
   (vals p a b) (map (\ x (evv x))
                     (sortby (\ u v ((evwb u) < (evwb v)))
                             (filter onset? (p (qi a) (qi b)))))

   ; --- cycle time: what harp leans on the tree's rationals for --------------
   ; not a re-test of `///` (l/boot/post.l owns that) -- these are the four
   ; properties the algebra would break without, stated where they can be read.
   _ (test ; exact, so a third of a cycle survives being multiplied back
             (((1 /// 3) * 3) = (1 /// 1))
             (((1 /// 3) + (1 /// 6)) = (1 /// 2))
             ; ordered by value and not by shape: (1 3) and (1 6) compare on 1/3
             ; against 1/6, which is the one a structural read gets backwards
             ((1 /// 6) < (1 /// 3))  !((1 /// 3) < (1 /// 6))
             ((-1 /// 2) < (1 /// 3)) ((7 /// 2) < (5 /// 1))
             ; equality by value, which is the whole of what onset? rests on
             ((qi 1) = (1 /// 1))  ((qi 2) = (4 /// 2))  !((qi 1) = (qi 2))
             ; and a rational does not meet a tray: it answers (), silently, so
             ; apps/harp/play.l crosses to frames through qnum and never after
             (nil? ((iota 4) + (1 /// 3)))
             ; // truncates toward zero; a floor that did not step down would
             ; put cycle -1/2 in cycle 0 and every negative span would be wrong
             (0  = qfl (1 /// 2))   (-1 = qfl (-1 /// 2))
             (-1 = qfl (-1 /// 1))  (-2 = qfl (-3 /// 2))
             (0.25 = qnum (1 /// 4)))

   ; --- the floor of the algebra ---------------------------------------------
   _ (test ((evs (pure 'a) 0 1) = [[0 1 'a]])
             ((evs (pure 'a) 0 3) = [[0 1 'a] [1 2 'a] [2 3 'a]])
             ((evs hush 0 4) = ())
             ((evs (fastcat [(pure 'a) (pure 'b)]) 0 1) = [[0 0.5 'a] [0.5 1 'b]])
             ; slowcat gives each member a cycle AND lets it advance only on its turn
             ((evs (slowcat [(pure 'a) (pure 'b)]) 0 2) = [[0 1 'a] [1 2 'b]])
             ((evs (slowcat [(fastcat [(pure 'a) (pure 'b)]) (pure 'c)]) 0 4)
              = [[0 0.5 'a] [0.5 1 'b] [1 2 'c] [2 2.5 'a] [2.5 3 'b] [3 4 'c]])
             (3 = cnt (fast (qi 3) (pure 'a)) 0 1)
             (2 = cnt (stack [(pure 'a) (pure 'b)]) 0 1))

   ; fast and slow undo each other, and rev is its own inverse -- the two laws a
   ; change of variable has to keep or the times have drifted
   pp (fastcat [(pure 'a) (pure 'b) (pure 'c)])
   _ (test ((evs (fast (qi 3) (slow (qi 3) pp)) 0 2) = (evs pp 0 2))
             ((evs (rev (rev pp)) 0 2) = (evs pp 0 2))
             ((evs (late (1 /// 4) (early (1 /// 4) pp)) 0 2) = (evs pp 0 2))
             ((vals (rev pp) 0 1) = ['c 'b 'a])
             ; rev is per cycle, so cycle 1 reverses too rather than running on
             ((vals (rev pp) 1 2) = ['c 'b 'a]))

   ; --- whole vs part: the difference a player reads -------------------------
   ; one event two cycles wide is struck in the cycle it begins and only sounds on
   ; through the next -- which is exactly the onset test, and the only thing that
   ; keeps a player from re-triggering a long note every cycle.
   sl (slow (qi 2) (pure 'a))
   _ (test (1 = cnt sl 0 1)  (1 = cnt sl 1 2)
             (onset? ((sl (qi 0) (qi 1)) 0))  !(onset? ((sl (qi 1) (qi 2)) 0))
             ((ons sl 0 2) = [[0 2 'a]])
             (1 = cnt (pure 'a) 0 1))
   ; a query that starts mid-cycle cuts the part and never the whole
   hev  ((pure 'a) (1 /// 2) (qi 1))
   _ (test (1 = #hev)  !(onset? (hev 0))
             ((qnum (evwb (hev 0))) = 0)  ((qnum (evpb (hev 0))) = 0.5))

   ; --- weights, windows, and the euclidean lane -----------------------------
   _ (test ((evs (timecat [((qi 3) . (pure 'a)) ((qi 1) . (pure 'b))]) 0 1)
              = [[0 0.75 'a] [0.75 1 'b]])
             ((evs (squeeze (1 /// 4) (1 /// 2) (pure 'a)) 0 1) = [[0.25 0.5 'a]])
             ; bjorklund's own answer for the three everybody knows
             ((bjork 3 8) = [1 0 0 1 0 0 1 0])
             ((bjork 5 8) = [1 0 1 1 0 1 1 0])
             ((bjork 2 5) = [1 0 1 0 0])
             (3 = #(ons (euclid 3 8 (pure 'a)) 0 1))
             (5 = #(ons (euclid 5 8 (pure 'a)) 0 1)))

   ; --- the cycle-indexed transforms -----------------------------------------
   ; every 2 fires on cycle 0 and not on cycle 1
   e2 (every 2 (fast (qi 2)) (pure 'a))
   _ (test (2 = cnt e2 0 1)  (1 = cnt e2 1 2)  (2 = cnt e2 2 3)
             ; iter rotates the sequence one step per cycle
             ((vals (iter 4 pp) 0 1) = ['a 'b 'c])
             ((vals (iter 4 pp) 1 2) = ['b 'c 'a])
             ((vals (palin pp) 0 1) = ['a 'b 'c])
             ((vals (palin pp) 1 2) = ['c 'b 'a])
             (4 = #(ons (seg (qi 4) (pure 'a)) 0 1))
             ; off stacks a shifted copy on the plain one: three fragments, two struck
             (3 = cnt (off (1 /// 4) (\ q q) (pure 'a)) 0 1)
             (2 = #(ons (off (1 /// 4) (\ q q) (pure 'a)) 0 1)))

   ; --- chance is a place, not a moment --------------------------------------
   ; the same span asked twice must answer the same, or a live loop stutters
   dg (degby 0.5 (fast (qi 16) (pure 'a)))
   _ (test ((evs dg 0 4) = (evs dg 0 4))
             (0 < #(evs dg 0 8))  (#(evs dg 0 8) < 128)
             ; and two `?`s in one sequence must not agree by construction
             ((#(evs (mini "a? b? c? d? e? f? g? h?") 0 8)) < 64))

   ; --- controls: tablets that merge -----------------------------------------
   hv ((hit (pure "bd")) (qi 0) (qi 1))
   _ (test (tablet? (evv (hv 0)))  ("bd" = (peep (evv (hv 0)) 's ()))
             ; # takes structure from the left and the value from the right
             ((: r ((pset (hit (pure "bd")) (note (pure 7))) (qi 0) (qi 1))
                 [(peep (evv (r 0)) 's ()) (peep (evv (r 0)) 'note ())])
              = ["bd" 7])
             ; jux is the same shape: two copies, hard left and hard right
             ((: r ((jux rev (hit (fastcat [(pure "bd") (pure "sn")]))) (qi 0) (qi 1))
                 (sort (map (\ x (peep (evv x) 'pan ())) r)))
              = [0.0 0.0 1.0 1.0]))

   ; --- mini-notation --------------------------------------------------------
   (m s) (map (\ x [(qnum (evwb x)) (qnum (evwe x)) (evv x)])
              (filter onset? ((mini s) (qi 0) (qi 1))))
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
             ((map (\ x (evv x)) (filter onset? ((mini "<bd sn>") (qi 1) (qi 2)))) = ["sn"])
             ; a comma stacks, at the top level and inside a bracket alike
             (6 = #(m "bd*2, hh*4"))
             (6 = #(m "[bd*2, hh*4]"))
             ; a sample index rides the value as a tablet, and `hit` leaves it alone
             ((: r (m "bd:3") v (<r 2) [(peep v 's ()) (peep v 'n ())]) = ["bd" 3])
             ; every step of a bad string is still a step: no hang, no scare
             (0 <= #(m "bd ] sn"))))

; --- the voices, at the far end only ----------------------------------------
; the pure half above is the gate; this half proves the pattern reaches PCM. it
; wants a filesystem and the horn's policy word, so it is hosted-only.
(: _ (? !(hosted && files) 0
        (: _ (setenv "HORN" "none")
           p (hit (mini "bd*2 [~ sn]"))
           w "out/.harp.wav"
           spc 24000                                   ; rate 24000, cps 1: one cycle
           _ (harp-wav p 0 1 24000 1 0 20000.0 w)
           q (open w "r")
           s (? (hot? q) (: b (slurp q) _ (close q) (b + "")) "")
           ; a canonical 44-byte riff header over exactly one cycle of stereo frames
           _ (test (("RIFF" = snip s 0 4)  ("WAVE" = snip s 8 12)
                      ("data" = snip s 36 40)
                      (#s = (44 + (spc * 4)))))
           ; the energy has to land where the pattern put it: a kick at 0 and at a
           ; quarter cycle, a snare at three quarters, and near-nothing between --
           ; the peak of n frames from frame a, left channel, sign-extended
           (pk a n) (: e (44 + ((a + n) * 4))
                       (go i m) (? (i >= e) m
                                   (: v ((s i) + ((s (i + 1)) << 8))
                                      u (? (v > 32767) (65536 - v) v)
                                      (go (i + 4) (? (u > m) u m))))
                       (go (44 + (a * 4)) 0))
           _ (test ((pk 0 2000) > 1000)                            ; kick
                     ((pk (spc // 4) 2000) > 1000)                   ; kick
                     ((pk ((spc * 3) // 4) 2000) > 1000)             ; snare
                     ; the `~` is a rest, not a silence: the second kick is still
                     ; ringing through it, so the law is the ratio and not a floor
                     ((10 * (pk ((spc * 2) // 3) 2000)) < (pk ((spc * 3) // 4) 2000)))
           ; and the timed sink keeps the clock: two cycles at cps 2 is one second,
           ; and the sink only holds a quarter of it, so most of that is real waiting
           t0 (clock 0)
           _ (harp-horn p 0 2 24000 2 0 20000.0)
           dt (clock t0)
           _ (test (dt >= 400) (dt < 8000))
           (setenv "HORN" ()))))

; the sentinel the gate reads
(say out "apps/harp/law: patterns, mini-notation, voices\n")
