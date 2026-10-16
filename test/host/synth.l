; test/host/synth.l -- the keyboard synth, headless: all but the tty runner
; not in the test/*.l corpus (it loads a crew module)
;   cat test/00-init.l test/host/synth.l | out/love

(borrow 'synth)
(borrow 'vi)      ; a buffer, for the loop's ex words
(borrow 'harp)    ; the events, to ask a text read by
(borrow 'play)    ; harp-read
(borrow 'drift)   ; a walk's state, to stand the center somewhere
(borrow 'opl)     ; a bank for the FM timbre
(borrow 'bytes)   ; zbytes
(borrow 'rove)    ; song-rate

(: d0 (synth-digits 0) d1 (synth-digits 1) s0 (synth-shifted 0)
   st (synth-new ())
   (semis c) (synth-semis st c))

; a key: a digit is a degree, its shifted mate adds shift, 256 past either is alt
(test (synth-code d0 = [0 0 0]) (synth-code d1 = [1 0 0]) (synth-code (synth-digits 11) = [11 0 0])
      (#synth-digits = 12) (#synth-shifted = 12)                 ; a chromatic octave, and its shifted row
      (synth-code s0 = [0 1 0]) (synth-code (256 + d0) = [0 0 1]) (synth-code (256 + s0) = [0 1 1])
      (synth-code 97 = ()) (synth-code 9 = ()) (synth-code -8 = ()))

; the bends: a key a semitone, shift an octave, alt half a semitone down
(: a (semis [0 0 0]) b (semis [1 0 0]) sh (semis [0 1 0]) al (semis [0 0 1]) bo (semis [0 1 1])
 (test (abs (b - a - 1.0) < 0.001) (abs (sh - a - 12.0) < 0.001)
       (abs (a - al - 0.5) < 0.001) (abs (bo - a - 11.5) < 0.001)
       (abs (semis [11 0 0] - a - 11.0) < 0.001)))

; a name: octaves of c, and cents under a quarter tone
(test (synth-name 0.0 = "C4") (synth-name 12.0 = "C5") (synth-name -12.0 = "C3")
      (synth-name -1.0 = "B3") (synth-name 1.0 = "C#4") (synth-name 11.0 = "B4")
      (has? (synth-name 0.5) "C4") (has? (synth-name 0.5) "50") !(has? (synth-name 0.0) "50")
      (has? (synth-name -0.5) "B3"))

; the timbre cycles round; the octave climbs and stops
(: st (synth-new ())
   t0 (st 'tim)
   seen (map (i \ (synth-step st 9, st 'tim)) ^#synth-timbres)
   _ (each ^20 (i \ synth-step st -8)) up (st 'oct)
   _ (each ^40 (i \ synth-step st -9)) down (st 'oct)
   _ (synth-step st -8) back (st 'oct)
 (test (st 'tim = t0) (#seen = #synth-timbres) (sort seen = ^#synth-timbres)
       (up = synth-octaves) (down = 0 - synth-octaves) (back = down + 1)
       (abs (synth-semis st [0 0 0] - 12.0 * back) < 0.001)))

; a strike rings into a jug; a dead voice is dropped
(: j (jug 0) st (synth-new ())
   _ (synth-feed st j) n0 #(slurp j)
   _ (synth-step st d0)
   _ (each ^10 (i \ synth-feed st j))
   out (slurp j)
   loud (net (map (i \ (out (n0 + i * 97) != 0 ? 1 0)) ^400))
   _ (each ^400 (i \ synth-feed st j))
   f (synth-frame st)
 (test (n0 = 4 * synth-chunk) (#out = 11 * 4 * synth-chunk) (10 < loud)
       (#(st 'vs) = 0) (string? (st 'last)) (has? f (st 'last))
       (has? f (synth-timbres (st 'tim) 0))))

; the loop: a sent text plays from the next chunk; a bad one is said and the old kept
(: j (jug 0) st (synth-new ())
   _ (synth-send st "bd sn")
   on (st 'on) m1 (st 'lmsg) good (st 'nextp)
   _ (each ^40 (i \ synth-feed st j)) out (slurp j)
   loud (net (map (i \ (out (i * 97) != 0 ? 1 0)) ^(#out // 97)))
   c1 (st 'cyc)
   ahead (two? (st 'due) && all (p \ (st 'fpos) <= p 0) (st 'due))   ; pulled voices wait for their start
   _ (synth-send st "(nosuch 1)") m3 (st 'lmsg) kept (st 'pat)     ; a bad form: said, and the playing one kept
   _ (synth-send st "(fast 2 (hit (mini \"bd\")))") m4 (st 'lmsg)
   _ (synth-send st "") m5 (st 'lmsg)
   _ (synth-stop st) off (st 'on) c2 (st 'cyc) gone (st 'due = ())
   _ (each ^400 (i \ synth-feed st j)) whole (slurp j)
   n #whole quiet (all (i \ 0 = whole (n - 1 - i)) ^(4 * synth-chunk))
   c3 (st 'cyc)
   _ (synth-cps! st 100.0) hi (st 'cps) _ (synth-cps! st 0.0) lo (st 'cps)
   _ (synth-cps! st 1.0, synth-step st 93) up (st 'cps) _ (synth-step st 91, synth-step st 91) down (st 'cps)
   _ (synth-step st 112) p1 (st 'on) _ (synth-step st 112) p2 (st 'on)
   (synth-step st 113,
    test (on = 1) (m1 = "sent") (0 < c1) (0 < loud) ahead gone
         (m3 != "sent") (kept != ()) (m4 = "sent") (m5 = "sent")
         (off = 0) (c2 = c3) quiet
         (hi = synth-cps-hi) (lo = synth-cps-lo)
         (abs (up - 1.0 - synth-cps-step) < 0.001) (abs (1.0 - synth-cps-step - down) < 0.001)
         (p1 = 1) (p2 = 0) (st 'over = 1)))

; the buffer's ex words: send, cps, stop, and a complaint for any other
(: st (synth-new ()) buf (vi-open "") _ (pin buf 'lines ["bd sn" "hh"])
   face (vi-face buf {'ex (synth-ex st)})
   (ex s) (":" + s @ t (map (face 1) (map (i \ t i) ^#t + [13])))
   _ (ex "send") m1 (buf 'msg) on (st 'on) t (st 'lmsg)
   _ (ex "cps 1") m2 (buf 'msg) c (st 'cps)
   _ (ex "cps") m3 (buf 'msg)
   _ (ex "stop") m4 (buf 'msg) off (st 'on)
   _ (ex "play") m5 (buf 'msg) back (st 'on)
   _ (ex "zz") m6 (buf 'msg)
 (test (m1 = "sent") (on = 1) (t = "sent") (c = 1.0) (0 < #m2) (0 < #m3)
       (m4 = "stopped") (off = 0) (m5 = "playing") (back = 1)
       (m6 = "not an ex command: zz")))

; a form's names are harp's even where the prel has one; leading comment lines are passed over
(: (evs p) (filter onset? (p (qi 0) (qi 1)))
   r (harp-read "(jux rev (hit (mini \"bd sn\")))")
   right (filter (x \ 1.0 = (evv x) 'pan) (evs r))
   bdr (filter (x \ "bd" = (evv x) 's) right)
   g (harp-read "(pset (hit (mini \"hh*4\")) (gain (range 0.0 1.0 sine)))")
   gs (map (x \ (evv x) 'gain) (evs g))
   c (harp-read "; a word first\n  ; and another\n(hit (mini \"bd*3\"))")
   m (harp-read "bd sn")
 (test (2 = #right) (1 = #bdr) (qhalf = evwb (bdr 0))      ; the right side is the cycle turned round
       (4 = #gs) (0 < net (map (x \ (x != gs 0)) gs))       ; a swell, not the prel's sin of a span
       (3 = #(evs c)) (2 = #(evs m))))

; the drift: d walks, k turns the row fixed, following, then just; d again stops
(: j (jug 0) st (synth-new ())
   _ (synth-step st 100) on (st 'dr) pl (st 'on)
   fix (synth-semis st [7 0 0])
   _ (synth-step st 107) k1 (st 'km)
   _ (pin st 'dnow {'tonic (5 /// 4) 'pos [0 1 0]}) fol (synth-semis st [7 0 0])
   _ (pin st 'dnow (drift-new {}))
   _ (synth-step st 107) k2 (st 'km)
   fifth (synth-semis st [7 0 0]) third (synth-semis st [4 0 0]) sev (synth-semis st [10 0 1])
   _ (synth-step st d0) lst (st 'last)
   _ (each ^60 (i \ synth-feed st j)) out (slurp j)
   loud (net (map (i \ (out (i * 97) != 0 ? 1 0)) ^(#out // 97)))
   c1 (st 'cyc) ph (st 'dph)
   _ (each ^20 (i \ synth-step st 46)) hi (st 'dsteer)
   _ (each ^20 (i \ synth-step st 44)) lo (st 'dsteer)
   _ (synth-step st 39) ln (st 'dlean)
   _ (synth-step st 118) bk (st 'dbook)
   _ (synth-step st 104) hm (st 'dhome)
   f (synth-frame st)
   _ (synth-step st 100) off (st 'dr) stop (st 'on)
 (test (on = 1) (pl = 1)
       (abs (fix - 7.0) < 0.001) (k1 = 1)                                ; fixed: the equal row
       (abs (fol - 3.86314 - 7.0) < 0.001) (k2 = 2)                      ; follow: rooted on 5/4
       (abs (fifth - 7.01955) < 0.001) (abs (third - 3.86314) < 0.001)   ; just: 3/2 and 5/4
       (abs (sev - 9.68826) < 0.001)                                     ; alt: 7/4
       (has? lst "1 C4")
       (0 < c1) (0 < loud) (0 < #ph)
       (hi = 2.0) (lo = -2.0) (ln = 2.0) (bk = 0) (abs (hm - 0.3) < 0.001)
       (has? f "drift") (has? f "[") (has? f (st 'dph))
       (off = 0) (stop = 0)
       ; a point's name: along the fifths, a comma under or over, the sevenths
       (synth-lname [0 0 0] = "C") (synth-lname [1 0 0] = "G") (synth-lname [-1 0 0] = "F")
       (synth-lname [0 1 0] = "E-") (synth-lname [0 -1 0] = "Ab+") (synth-lname [0 0 1] = "Bb7")
       (synth-lname [4 -1 0] = "C+")))

; the window: a held key holds its note, repeats add none, up lets it fade
(: j (jug 0) st (synth-new ())
   (loud o a n) (net (map (i \ (o (a + i * 97) != 0 ? 1 0)) ^n))
   _ (synth-wstep st ['down 16]) _ (synth-wstep st ['down 16]) one (#(st 'hv))
   _ (synth-wstep st ['down 44]) two (#(st 'hv)) names (synth-wframe st)
   _ (each ^240 (i \ synth-feed st j)) _ (slurp j)                ; four seconds: a strike is long gone
   _ (each ^10 (i \ synth-feed st j)) held (slurp j)
   _ (synth-wstep st ['up 16]) after (#(st 'hv)) fading (#(st 'vs))
   _ (synth-wstep st ['up 44])
   _ (each ^30 (i \ synth-feed st j)) out (slurp j)
   n #out quiet (all (i \ 0 = out (n - 1 - i)) ^(4 * synth-chunk))
   _ (synth-wstep st ['down 15]) tim (st 'tim)
   _ (synth-wstep st ['down 328]) up (st 'oct) _ (synth-wstep st ['down 336]) _ (synth-wstep st ['down 336]) down (st 'oct)
   _ (synth-wstep st ['down 30]) none (#(st 'hv))                  ; a: no note
   _ (synth-wstep st ['down 1]) over (st 'over)
   s2 (synth-new ()) _ (synth-wstep s2 ['close])
 (test (synth-qwerty 44 = -12) (synth-qwerty 16 = 0) (synth-qwerty 51 = 0) (synth-qwerty 27 = 19)
       (one = 1) (two = 2) (has? names "C4") (has? names "C3")
       (100 < loud held 0 300) (after = 1) (fading = 1) (#(st 'hv) = 0) (#(st 'vs) = 0) quiet
       (tim = 1) (up = 1) (down = -1) (none = 0) (over = 1) (s2 'over = 1)))

; the strip: a held key's note lit, its sharps short
(: w 640 h 400 win {'w w 'h h 'paper (cask (w * h * 4))} st (synth-new ())
   (rgb x y) (4 * (y * w + x) @ i (string (win 'paper) @ p [(p (i + 2)) (p (i + 1)) (p i)]))
   y0 (synth-trows * 16 + 16) cw (w // 32)
   _ (synth-wstep st ['down 16])                                    ; q: middle c, the 13th cell
   _ (synth-paint st win)
   c (rgb (12 * cw + cw // 2) (y0 + 4)) d (rgb (14 * cw + cw // 2) (y0 + 4))
   cs (rgb (13 * cw + cw // 2) (y0 + 4)) csl (rgb (13 * cw + cw // 2) (y0 + 90))
   _ (synth-wstep st ['up 16]) _ (synth-paint st win)
   c2 (rgb (12 * cw + cw // 2) (y0 + 4))
 (test (c = [255 128 0]) (d = [208 208 208]) (cs = [56 56 56]) (csl = [0 0 0])
       (c2 = [208 208 208])))

; --- the FM timbre: with a bank it is the last; left and right choose its instrument, a strike
; --- and a held key sound through it, and a key let go rings out its release
(: (syn-fm-b l) (foldl (\ a c (a + string c)) "" l)
   ; ..one instrument, a sine (the modulator silent), held while the key is; the rest empty
   v (syn-fm-b [33 240 15 0 0 63 0 33 240 15 0 0 0 0 0 0])
   B (opl-bank ("#OPL_II#" + syn-fm-b [0 0 128 0] + v + v + zbytes (174 * 36) + "sine" + zbytes (28 + 174 * 32)))
   j (jug 0) st (synth-new {'fm B})
   n0 #(synth-tims st)
   _ (pin st 'tim (n0 - 1)) nm (synth-tname st)
   _ (synth-step st -11) back (st 'prog) _ (synth-step st -10) fwd (st 'prog)
   _ (synth-step st 49) struck #(st 'vs)
   _ (each ^10 (i \ synth-feed st j)) rang (slurp j)
   _ (synth-wstep st ['down 16]) hv (st 'hv)
   _ (each ^10 (i \ synth-feed st j)) held (slurp j)
   _ (synth-wstep st ['up 16]) let (st 'vs)
 (test (n0 = #synth-timbres + 1) (#(synth-tims (synth-new ())) = #synth-timbres) (nm = "fm 0 sine")
       (back = 174) (fwd = 0) (struck = 1) (any (i \ rang i != 0) ^#rang)
       (#hv = 1) (#(<hv) = 5) (any (i \ held i != 0) ^#held)
       (any (v \ v 0 < st 'fpos + 10 * song-rate) let)))

(test_fin (),
 puts "synth: ok -- the keys bend as they should, the names are right, the turns stop, a strike rings, the loop plays what the buffer says, a held key holds, and the FM timbre plays\n")
