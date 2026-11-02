; test/host/synth.l -- the keyboard synth, headless: all but the tty runner. a crew module,
; not in the corpus:
;   cat test/00-init.l test/host/synth.l | out/love

(borrow 'synth)
(borrow 'vi)      ; a buffer, for the loop's ex words
(borrow 'harp)    ; the events, to ask a text read by
(borrow 'play)    ; harp-read
(borrow 'opl)     ; a bank for the FM timbre
(borrow 'bytes)   ; zbytes
(borrow 'rove)    ; song-rate

; a tty byte is where its key sits, shifted or not; a key with no byte is 1000 past its place
(test (synth-tcode 113 = 16) (synth-tcode 81 = 16) (synth-tcode 122 = 44) (synth-tcode 93 = 27) (synth-tcode 125 = 27)
      (synth-tcode 27 = 1) (synth-tcode 9 = 15) (synth-tcode 13 = 28) (synth-tcode 1059 = 59) (synth-tcode 97 = ()))

; the notes: z an octave under middle c, q middle c, 2 its sharp, ] the g above the next c; the
; octave moves them all
(: (last k) (: st (synth-new ()) (synth-step st k, st 'last))
   st (synth-new ()) _ (synth-step st 1328) _ (synth-step st 113) up (st 'last)
 (test (last 113 = "C4") (last 122 = "C3") (last 50 = "C#4") (last 93 = "G5") (last 47 = "E4")
       (last 97 = ()) (up = "C5")))

; an escape's tail is read whole: f keys in xterm's spelling, the console's and rxvt's, a
; modified one, the arrows; an escape then a letter is the escape, the letter kept
(: j (tap (chars "\eOP\e[15~\e[1;2S\e[[A\e[11~\e[A\eOB\e[24~\e[6~q\ez"))
   ks (map (_ \ synth-key j) ^12)
 (test (ks = [1059 1063 1062 1059 1059 1328 1336 1088 1337 113 27 122])))

; a name: octaves of c, and cents under a quarter tone
(test (synth-name 0.0 = "C4") (synth-name 12.0 = "C5") (synth-name -12.0 = "C3")
      (synth-name -1.0 = "B3") (synth-name 1.0 = "C#4") (synth-name 11.0 = "B4")
      (has? (synth-name 0.5) "C4") (has? (synth-name 0.5) "50") !(has? (synth-name 0.0) "50")
      (has? (synth-name -0.5) "B3"))

; the timbre cycles round; the octave climbs and stops
(: st (synth-new ())
   t0 (st 'tim)
   seen (map (i \ (synth-step st 9, st 'tim)) ^#synth-timbres)
   _ (each ^20 (i \ synth-step st 1328)) up (st 'oct)
   _ (each ^40 (i \ synth-step st 1336)) down (st 'oct)
   _ (synth-step st 1328) back (st 'oct)
 (test (st 'tim = t0) (#seen = #synth-timbres) (sort seen = ^#synth-timbres)
       (up = synth-octaves) (down = 0 - synth-octaves) (back = down + 1)
       (synth-step st 113, st 'last = synth-name (12.0 * back))))

; a strike rings into a jug; a dead voice is dropped
(: j (jug 0) st (synth-new ())
   _ (synth-feed st j) n0 #(slurp j)
   _ (synth-step st 113)
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
   _ (synth-cps! st 1.0, synth-step st 1329) up (st 'cps) _ (synth-step st 1337, synth-step st 1337) down (st 'cps)
   _ (synth-step st 1068) p1 (st 'on) _ (synth-step st 1068) p2 (st 'on)
   (synth-step st 27,
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

; a finger on the strip holds its key's note and lights it, a slide takes the next key, up lets
; it go; a press over the text holds nothing
(: w 640 h 400 win {'w w 'h h 'paper (cask (w * h * 4))} st (synth-new ())
   (rgb x y) (4 * (y * w + x) @ i (string (win 'paper) @ p [(p (i + 2)) (p (i + 1)) (p i)]))
   y0 (synth-trows * 16 + 16) cw (w // 32)
   _ (synth-wlay st w h)
   _ (synth-wstep st ['press 1 (12 * cw + 3) (y0 + 10)]) n1 (map (p \ p 1) (st 'hv))
   _ (synth-paint st win) lit (rgb (12 * cw + cw // 2) (y0 + 4))
   _ (synth-wstep st ['move (14 * cw + 3) (y0 + 10)]) n2 (map (p \ p 1) (st 'hv)) fading (#(st 'vs))
   _ (synth-wstep st ['move (14 * cw + 5) (y0 + 12)]) n3 (map (p \ p 1) (st 'hv))
   _ (synth-wstep st ['release 1 (14 * cw + 5) (y0 + 12)]) n4 (#(st 'hv))
   _ (synth-wstep st ['press 1 30 30]) n5 (#(st 'hv))
   ls (synth-new ()) _ (synth-wlay ls w h) _ (synth-step ls 1062)
   _ (synth-wstep ls ['press 1 (12 * cw + 3) (y0 + 10)]) _ (synth-wstep ls ['release 1 (12 * cw + 3) (y0 + 10)]) l1 (#(ls 'hv))
   _ (synth-wstep ls ['press 1 (12 * cw + 3) (y0 + 10)]) l2 (#(ls 'hv))
 (test (n1 = [0.0]) (lit = [255 128 0]) (n2 = [2.0]) (fading = 1) (n3 = [2.0]) (n4 = 0) (n5 = 0)
       (synth-cell st w h (12 * cw) (y0 - 1) = ()) (synth-cell st w h (31 * cw) y0 = 31)
       (l1 = 1) (l2 = 0)))

; the window's buffer, under the keys: ctrl-w w goes between them, a click on the buffer gives
; it the keys; there the keys type, esc is vi's, :send sends; enter on the keys sends it too
(: w 640 h (synth-top + 320) win {'w w 'h h 'paper (cask (w * h * 4))} st (synth-new ())
   (any-lit y0 y1) (: p (win 'paper) (any (i \ p (4 * (y0 * w) + i) != 0) ^(4 * w * (y1 - y0))))
   vs (vi-open "")
   _ (synth-wedit st (cite 'vi) vs w h)
   _ (synth-paint st win) drawn (any-lit synth-top h)
   (ev r) (synth-wstep st r)
   (keys l) (each l ev)
   (typed t) (each (chars t) (c \ ev ['text (string c)]))
   f0 (st 'focus)
   _ (keys [['down 29] ['down 17] ['up 17] ['up 29] ['down 17]]) f1 (st 'focus)      ; ctrl-w w, then w
   _ (typed "w") nv (#(st 'hv)) _ (keys [['down 18] ['up 18]]) _ (typed "i") _ (typed "bd sn")
   _ (keys [['down 1] ['up 1]]) md (vs 'mode) ov (st 'over)
   ln (vs 'lines)
   _ (keys [['down 29] ['down 17] ['up 17] ['up 29] ['down 37]]) f2 (st 'focus)      ; ctrl-w k
   _ (keys [['down 28] ['up 28]]) sent (st 'lmsg) on (st 'on)
   _ (synth-wstep st ['press 1 10 (synth-top + 40)]) f3 (st 'focus)
   _ (synth-wstep st ['press 1 10 10]) f4 (st 'focus)
   _ (synth-wstep st ['press 1 10 (synth-top + 40)])
   _ (synth-paint st win)
   _ (typed ":q!") _ (keys [['down 28]])
 (test (synth-trows * 16 + 16 + 96 < synth-top) drawn (f0 = 'keys) (f1 = 'vi) (nv = 0)
       (md = 'n) (ov = 0) (ln = ["bd sn"]) (f2 = 'keys) (sent = "sent") (on = 1)
       (f3 = 'vi) (f4 = 'keys) (st 'over = 1)
       (has? (synth-wframe st) "ctrl-w w") !(has? (synth-wframe (synth-new ())) "ctrl-w w")))

; --- the FM timbre: with a bank it is the last; left and right choose the instrument, a strike
; --- and a held key sound through it, a let-go key rings out its release
(: (syn-fm-b l) (foldl (\ a c (a + string c)) "" l)
   ; ..one instrument, a sine (the modulator silent), held while the key is; the rest empty
   v (syn-fm-b [33 240 15 0 0 63 0 33 240 15 0 0 0 0 0 0])
   B (opl-bank ("#OPL_II#" + syn-fm-b [0 0 128 0] + v + v + zbytes (174 * 36) + "sine" + zbytes (28 + 174 * 32)))
   j (jug 0) st (synth-new {'fm B})
   n0 #(synth-tims st)
   _ (pin st 'tim (n0 - 1)) nm (synth-tname st)
   _ (synth-step st 1331) back (st 'prog) _ (synth-step st 1333) fwd (st 'prog)
   _ (synth-step st 113) struck #(st 'vs)
   _ (each ^10 (i \ synth-feed st j)) rang (slurp j)
   _ (synth-wstep st ['down 16]) hv (st 'hv)
   _ (each ^10 (i \ synth-feed st j)) held (slurp j)
   _ (synth-wstep st ['up 16]) let (st 'vs)
 (test (n0 = #synth-timbres + 1) (#(synth-tims (synth-new ())) = #synth-timbres) (nm = "fm 0 sine")
       (back = 174) (fwd = 0) (struck = 1) (any (i \ rang i != 0) ^#rang)
       (#hv = 1) (#(<hv) = 5) (any (i \ held i != 0) ^#held)
       (any (v \ v 0 < st 'fpos + 10 * song-rate) let)))

; --- the bus: the kernel asks its memory's size, an echo lands on its frame and crosses over,
; --- the reverb loses 60 dB in its t60, and the same input answers the same frames
(: K (cite 'dsp 'space) n 735 z (iota n * 0.0) imp ((iota n = 0) * 1.0)
   (P o) (gem-tray [16] (map (k \ 1.0 * peep o k 0.0) ^16))
   (e c) (net (<c * <c + >c * >c))
   PE (P {0 44100 5 1 6 1 7 0.01 8 0.5 9 1})
   sz (K z z () PE) m (cask sz)
   _ (K z z m PE) e1 (K imp z m PE) e2 (K z z m PE)
   PR (P {0 44100 10 1 11 1 12 1.0 13 1 14 0})
   (verb _) (: m (cask sz) _ (K z z m PR) r0 (K imp z m PR) (r0 . map (_ \ K z z m PR) ^60))
   v1 (verb ()) v2 (verb ())
   ratio (e (v1 40) / e (v1 10))
 (test (charm? sz) (0 < sz) (K z z (cask 8) PE = sz) (K z z m (P {0 10}) = ())
       (abs (peep <e1 0 0.0 - 1.0) < 1e-9) (abs (peep <e1 441 0.0 - 1.0) < 1e-6) (abs (peep <e1 440 1.0) < 1e-9)
       (amax (>e1 * >e1) = 0.0) (abs (peep >e2 147 0.0 - 0.5) < 1e-6)               ; fed back to the right at 882
       (0.0 < e (v1 0)) (1e-4 < ratio) (ratio < 1e-2)                       ; 30 dB down in half a second
       (all (i \ aall (<(v1 i) = <(v2 i)) && aall (>(v1 i) = >(v2 i))) ^61)))

; the shimmer: the tail comes back an octave up, so it rings longer and brighter, and at its
; deepest over the longest reverb it still dies away
(: K (cite 'dsp 'space) n 735 z (iota n * 0.0)
   tone (sin (iota n * (tau * 220.0 / 44100.0)))
   (P o) (gem-tray [16] (map (k \ 1.0 * peep o k 0.0) ^16))
   (e c) (net (<c * <c + >c * >c))
   (zc t) (net (map (i \ peep t i 0.0 * peep t (i + 1) 0.0 < 0.0) ^(n - 1)))   ; sign changes
   (tail sh t60 sz k) (: pr (P {0 44100 10 1 11 1 12 t60 13 sz 14 0.45 15 sh}) m (cask (K z z () pr))
                         _ (map (_ \ K tone tone m pr) ^30)
                         (map (_ \ K z z m pr) ^k))
   a0 (tail 0.0 7.0 1.6 600) a1 (tail 1.0 7.0 1.6 600) a2 (tail 1.0 7.0 1.6 600)
   lng (tail 1.0 30.0 3.0 1500)
 (test (e (a0 599) * 20.0 < e (a1 599))                            ; ten seconds on, far louder
       (zc <(a0 120) * 1.5 < zc <(a1 120))                         ; and higher
       (all (i \ aall (<(a1 i) = <(a2 i)) && aall (>(a1 i) = >(a2 i))) [0 120 599])
       (e (lng 1499) < e (lng 500) * 0.1)))

; synth's bus: a toggle and a wetter step a key, a reverb's tail outlasts the note, a toggle
; off lets it ring out, the bus at its wettest stays under the clip, and two runs are one
(: (run st k) (map (_ \ synth-mix st) ^k)
   (en cs) (net (map (c \ net (<c * <c + >c * >c)) cs))
   (pk cs) (foldl max 0.0 (map (c \ max (amax (<c * <c)) (amax (>c * >c))) cs))
   wet (synth-new ()) dry (synth-new ())
   _ (synth-step wet 1059) r1 (wet 'rev) _ (synth-step wet 1063) w1 (wet 'rvw)
   _ (synth-step wet 1063) _ (synth-step wet 1063) w2 (wet 'rvw)
   _ (pin wet 'rvw 2)
   _ (synth-step wet 113) _ (synth-step dry 113)
   cw (run wet 180) cd (run dry 180)
   late (en (drop 140 cw)) dlate (en (drop 140 cd))
   _ (synth-step wet 1059) r2 (wet 'rev) t0 (wet 'fxt)
   _ (run wet 1) t1 (wet 'fxt) ring (en (run wet 30))
   f (synth-frame wet)
   (loud _) (: st (synth-new ())
               (each [1059 1063 1063 1060 1064 1064 1064 1061 1065 1065 1066 1067 1067 9 9] (k \ synth-step st k),
                each [113 101 116] (k \ synth-step st k),
                run st 300))
   l1 (loud ()) l2 (loud ())
   ws (synth-new ()) _ (synth-wstep ws ['down 59]) _ (synth-wstep ws ['down 63]) _ (synth-wstep ws ['down 61])
   _ (synth-wstep ws ['down 66]) _ (synth-wstep ws ['down 67])
   sh (synth-new ()) _ (synth-step sh 1059) _ (synth-step sh 1066) _ (synth-step sh 113) _ (run sh 1) st0 (sh 'fxt)
 (test (r1 = 1) (w1 = 3) (w2 = 0) (0.0 < late) (dlate = 0.0)
       (r2 = 0) (t0 = synth-ftail) (t1 = t0 - synth-chunk) (0.0 < ring)
       (has? f "reverb off") (has? f "echo off")
       (pk l1 * synth-gain * synth-gain < 32767.0 * 32767.0)
       (all (i \ aall (<(l1 i) = <(l2 i)) && aall (>(l1 i) = >(l2 i))) ^#l1)
       (ws 'rev = 1) (ws 'rvw = 3) (ws 'cho = 1)
       (has? (synth-wframe ws) "chorus 0.5")
       (ws 'shm = 1) (ws 'shw = 3) (has? (synth-wframe ws) "shimmer 0.7")
       (sh 'shm = 1) (st0 = synth-stail) (synth-ftail < synth-stail) (has? (synth-frame sh) "shimmer 0.5")))

; --- the swept filter: a lowpass keeps what is under its cutoff and stops what is far over it,
; --- a bandpass is unity at its peak, and a run cut anywhere answers what it does whole
(: S (cite 'dsp 'sweep) n 4410
   (tone f) (sin (iota n * (tau * f / 44100.0)))
   (P o) (gem-tray [8] (map (k \ 1.0 * peep o k 0.0) ^8))
   (rms t) (sqrt (net (t * t * (iota n >= 2205)) / 2205.0))            ; past the filter's settling
   lp (P {0 44100 2 200 6 0.707}) bp (P {0 44100 2 1000 6 4 7 1})
   lo (<(S (tone 50.0) () lp)) hi (<(S (tone 5000.0) () lp)) pk (<(S (tone 1000.0) () bp))
   SW (P {0 44100 1 0 2 800 3 1.5 4 3.0 5 0.2 6 1.5})
   x (tone 330.0 + tone 2900.0)
   whole (<(S x () SW))
   h1 (S (gem-tray [735] (map (i \ peep x i 0.0) ^735)) () SW)
   h2 (S (gem-tray [(n - 735)] (map (i \ peep x (735 + i) 0.0) ^(n - 735))) (>h1) (P {0 44100 1 735 2 800 3 1.5 4 3.0 5 0.2 6 1.5}))
 (test (0.65 < rms lo) (rms hi < 0.01) (0.65 < rms pk) (rms pk < 0.75)          ; a unit sine is 0.707
       (S x () (P {0 10 6 1}) = ())
       (all (i \ peep whole i 0.0 = peep <h1 i 1.0) ^735)
       (all (i \ peep whole (735 + i) 0.0 = peep <h2 i 1.0) ^(n - 735))))

; the pads: a strike swells in on two sides that differ and rings past its swell; a held one
; holds a voice a side and, let go, fades over its release; under the clip at the wettest bus
(: (run st k) (map (_ \ synth-mix st) ^k)
   (en cs) (net (map (c \ net (<c * <c + >c * >c)) cs))
   (side cs) (net (map (c \ net ((<c - >c) * (<c - >c))) cs))
   (pk cs) (foldl max 0.0 (map (c \ max (amax (<c * <c)) (amax (>c * >c))) cs))
   (at l x) (<l = x ? 0 (1 + at >l x))
   (pst nm) (: st (synth-new ()) (pin st 'tim (at (map (p \ p 0) synth-timbres) nm)))   ; pin answers st
   ps (pst "pad") _ (synth-step ps 113) cs (run ps 240)
   gs (pst "glass") _ (synth-step gs 113) cg (run gs 240)
   wa (pst "wash") _ (synth-step wa 113) cw (run wa 240)
   hs (pst "pad") _ (synth-wstep hs ['down 16]) nv (#(hs 'hv)) _ (run hs 120)
   _ (synth-wstep hs ['up 16]) rl (hs 'rls 16) fading (#(hs 'vs))
   r1 (run hs 60) r2 (run hs 180) r3 (run hs 30)
   (loud _) (: st (pst "pad")
               (each [1059 1063 1063 1060 1064 1064 1064 1061 1065 1065] (k \ synth-step st k),
                each [113 101 116] (k \ synth-step st k),
                run st 420))
   l1 (loud ()) l2 (loud ())
 (test (all (nm \ elem nm (map (p \ p 0) synth-timbres)) ["pad" "glass" "wash"])
       (en (take 6 cs) < en (take 6 (drop 60 cs)))           ; a tenth of a second against one past
       (0.0 < side cs) (0.0 < en (drop 180 cs))               ; two sides; rings past three seconds
       (0.0 < en cg) (0.0 < en cw) (0.0 < side cw)
       (nv = 2) (abs (rl - 3.0) < 1e-9) (fading = 2) (#(hs 'hv) = 0)
       (0.0 < en r1) (en r3 = 0.0)                           ; heard a second on, silent past three
       (pk l1 * synth-gain * synth-gain < 32767.0 * 32767.0)
       (all (i \ aall (<(l1 i) = <(l2 i)) && aall (>(l1 i) = >(l2 i))) ^#l1)))

; the latch: a struck note holds past any strike's length until struck again, then fades;
; letting the latch go fades them all, and the window's keys latch on their downs
(: (run st k) (map (_ \ synth-mix st) ^k)
   (en cs) (net (map (c \ net (<c * <c + >c * >c)) cs))
   (at l x) (<l = x ? 0 (1 + at >l x))
   ps (synth-new ()) _ (pin ps 'tim (at (map (p \ p 0) synth-timbres) "pad"))
   _ (synth-step ps 1062) _ (synth-step ps 113) n1 (#(ps 'hv)) f1 (synth-frame ps)
   c1 (run ps 600) n2 (#(ps 'hv))
   _ (synth-step ps 113) n3 (#(ps 'hv)) c2 (run ps 300)
   ss (synth-new ()) _ (synth-step ss 1062)
   _ (each [113 101 116] (k \ synth-step ss k)) m1 (#(ss 'hv))
   _ (synth-step ss 1062) m2 (#(ss 'hv)) m3 (#(ss 'vs)) c3 (run ss 60)
   ws (synth-new ()) _ (synth-wstep ws ['down 62])
   _ (synth-wstep ws ['down 16]) _ (synth-wstep ws ['up 16]) w1 (#(ws 'hv))
   _ (synth-wstep ws ['down 16]) w2 (#(ws 'hv))
 (test (n1 = 2) (has? f1 "latched") (n2 = 2) (0.0 < en (drop 540 c1))      ; ringing ten seconds on
       (n3 = 0) (0.0 < en (take 30 c2)) (en (drop 270 c2) = 0.0)
       (m1 = 3) (m2 = 0) (ss 'latch = 0) (3 <= m3) (en (drop 30 c3) = 0.0)
       (ws 'latch = 1) (w1 = 2 || w1 = 1) (w2 = 0)
       (has? (synth-wframe ws) "f4: latch")))

; the limiter: under its knee the pair passes as it came; past it one gain bends both sides
; toward the ceiling and never through it, the louder still the louder
(: Lm (cite 'dsp 'limit) n 735
   (P c) (gem-tray [4] [44100.0 c 0.5 0.4])
   (sine a) (sin (iota n * (tau * 110.0 / 44100.0)) * a)
   z (iota n * 0.0)
   sz (Lm z z () (P 1.0))
   (lim l r c) (: m (cask sz) (Lm l r m (P c)))
   q (lim (sine 0.4) (sine -0.2) 1.0)
   (top a) (: m (cask sz) cs (map (_ \ Lm (sine a) (sine (a / 2.0)) m (P 1.0)) ^4)
              (foldl max 0.0 (map (c \ amax (<c * <c)) cs)))
   h (lim (sine 8.0) (sine 2.0) 1.0)
 (test (charm? sz) (0 < sz) (Lm z z (cask 1) (P 1.0) = sz) (Lm z z (cask sz) (P 0.0) = ())
       (aall (<q = sine 0.4)) (aall (>q = sine -0.2))                 ; under the knee, untouched
       (top 2.0 < 1.0) (top 50.0 < 1.0) (top 2.0 < top 8.0)
       (all (i \ abs (peep <h i 0.0 - 4.0 * peep >h i 0.0) < 1e-9) ^n)))   ; one gain, both sides

; the latch's pile -- a wash, three pads and a glass over a wet bus -- stays under the clip
(: (at l x) (<l = x ? 0 (1 + at >l x))
   st (synth-new ())
   (tim nm) (pin st 'tim (at (map (p \ p 0) synth-timbres) nm))
   (run k) (map (_ \ synth-mix st) ^k)
   (pk cs) (foldl max 0.0 (map (c \ max (amax (<c * <c)) (amax (>c * >c))) cs))
   _ (each [1059 1063 1063 1066 1067 1062] (k \ synth-step st k))
   _ (tim "wash") _ (synth-drone st -24.0) c1 (run 120)
   _ (tim "pad") _ (synth-drone st -12.0) _ (synth-drone st -5.0) _ (synth-drone st 4.0) c2 (run 360)
   _ (tim "glass") _ (synth-strike st 16.0) _ (synth-strike st 19.0) _ (synth-strike st 23.0) c3 (run 600)
 (test (pk (c1 + c2 + c3) < synth-ceil * synth-ceil)
       (synth-ceil * synth-gain < 32767.0)
       (synth-ceil * 0.3 < sqrt (pk c3))))                              ; loud, bent, not crushed

; the volume: } up and { down, stopping at the ends; at nought the horn hears silence, at
; the top the loudest pile still bends under the clip, the bytes louder than at 1.0
(: st (synth-new ())
   v0 (st 'vol)
   _ (each ^20 (i \ synth-step st 1088)) top (st 'vol)
   _ (each ^40 (i \ synth-step st 1087)) bot (st 'vol)
   (pk cs) (foldl max 0.0 (map (c \ max (amax (<c * <c)) (amax (>c * >c))) cs))
   (s16 b i) (: u (b (2 * i) + 256 * b (2 * i + 1)) (u > 32767 ? (u - 65536) u))
   cv (synth-ceil / synth-vols (#synth-vols - 1))
   (loud v) (: s (synth-new ()) j (jug 0)
               _ (pin s 'vol v)
               _ (each [1059 1063 1063 1066 1067 1062] (k \ synth-step s k))
               _ (each [-24.0 -12.0 -5.0 4.0 7.0] (n \ synth-drone s n))
               ms (map (_ \ synth-mix s) ^240)
               _ (each ^60 (i \ synth-feed s j)) b (slurp j)
               [(pk ms) (foldl max 0 (map (i \ abs (s16 b i)) ^(#b // 2)))])
   hi (loud (#synth-vols - 1)) one (loud synth-vol0)
   _ (each ^9 (i \ synth-step st 1088))
   z (jug 0) _ (each ^10 (i \ synth-feed (pins (synth-new ()) 'vol 0) z)) zb (slurp z)
 (test (synth-vols v0 = 1.0) (top = #synth-vols - 1) (bot = 0) (st 'vol = 9)
       (has? (synth-frame st) "volume 1.0")
       (0 < #zb) (all (i \ zb i = 0) ^#zb)
       (<hi < cv * cv)
       (one 1 < hi 1) (hi 1 < 32767)))

(test_fin (),
 puts "synth: ok -- the keys sit where they should, an f key reads whole, the names are right, the turns stop, a strike rings, the loop plays what the buffer says, a held key holds, a finger plays the strip, the buffer sits under the window's keys, the FM timbre plays, the latch holds, and the bus rings and shimmers on under the clip, a limiter keeping it there, and the volume turns\n")
