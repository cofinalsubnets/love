; --- test/host/synth.l: the keyboard synth, headless ---
; not in the test/*.l corpus (it loads a crew module). the keys, the notes and the feed
; are pure, so everything but the tty runner gates here: a key into a degree and its
; bends, the bends' sizes against each other, a note's name, the timbre and octave
; turned and bounded, and a strike ringing into a jug.
;   cat test/00-init.l test/host/synth.l | out/love

(borrow 'synth)   ; the artifact's module, warm from the tree
(borrow 'vi)      ; a buffer, for the loop's ex words
(borrow 'harp)    ; the events, to ask a text read by
(borrow 'play)    ; harp-read

(: (find h n i) (i + #n < 1 + #h ? (n = snip h i (i + #n) ? 1 (find h n (i + 1))) 0)
   (has? h n) (find h n 0)
   d0 (synth-digits 0) d1 (synth-digits 1) s0 (synth-shifted 0)
   st (synth-new ())
   (semis c) (synth-semis st c))

; --- a key: a digit is a degree, its shifted mate the same with shift, 256 past either
; --- is alt, and any other key is nothing
(test (synth-code d0 = [0 0 0]) (synth-code d1 = [1 0 0]) (synth-code (synth-digits 11) = [11 0 0])
      (#synth-digits = 12) (#synth-shifted = 12)                 ; a chromatic octave, and its shifted row
      (synth-code s0 = [0 1 0]) (synth-code (256 + d0) = [0 0 1]) (synth-code (256 + s0) = [0 1 1])
      (synth-code 97 = ()) (synth-code 9 = ()) (synth-code -8 = ()))

; --- the bends against each other: a key on is a semitone, the last key of the row an
; --- octave less one, shift the octave, alt half a semitone down, both together both
(: a (semis [0 0 0]) b (semis [1 0 0]) sh (semis [0 1 0]) al (semis [0 0 1]) bo (semis [0 1 1])
 (test (abs (b - a - 1.0) < 0.001) (abs (sh - a - 12.0) < 0.001)
       (abs (a - al - 0.5) < 0.001) (abs (bo - a - 11.5) < 0.001)
       (abs (semis [11 0 0] - a - 11.0) < 0.001)))

; --- a name: middle c and its octaves, the semitone under a quarter tone said in cents
(test (synth-name 0.0 = "C4") (synth-name 12.0 = "C5") (synth-name -12.0 = "C3")
      (synth-name -1.0 = "B3") (synth-name 1.0 = "C#4") (synth-name 11.0 = "B4")
      (has? (synth-name 0.5) "C4") (has? (synth-name 0.5) "50") (!(has? (synth-name 0.0) "50"))
      (has? (synth-name -0.5) "B3"))

; --- the timbre cycles through them all and round; the octave climbs and stops --------
(: st (synth-new ())
   t0 (st 'tim)
   seen (map (i \ (synth-step st 9, st 'tim)) ^#synth-timbres)
   _ (each ^20 (i \ synth-step st -8)) up (st 'oct)
   _ (each ^40 (i \ synth-step st -9)) down (st 'oct)
   _ (synth-step st -8) back (st 'oct)
 (test (st 'tim = t0) (#seen = #synth-timbres) (sort seen = ^#synth-timbres)
       (up = synth-octaves) (down = 0 - synth-octaves) (back = down + 1)
       (abs (synth-semis st [0 0 0] - 12.0 * back) < 0.001)))

; --- a strike rings into a jug: a chunk a feed, sound after the strike and a note held
; --- for the screen; a voice that has died is dropped
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

; --- the loop: a text sent is read as harp reads it and plays from the next chunk,
; --- its cycles ringing into the jug; a bad one is said and the sent one kept; stopped,
; --- it rings out to silence; the cps is bounded, and the keys turn it all
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
   _ (synth-cps! st 1.0) _ (synth-step st 93) up (st 'cps) _ (synth-step st 91) _ (synth-step st 91) down (st 'cps)
   _ (synth-step st 112) p1 (st 'on) _ (synth-step st 112) p2 (st 'on)
   _ (synth-step st 113)
 (test (on = 1) (m1 = "sent") (0 < c1) (0 < loud) ahead gone
       (m3 != "sent") (kept != ()) (m4 = "sent") (m5 = "sent")
       (off = 0) (c2 = c3) quiet
       (hi = synth-cps-hi) (lo = synth-cps-lo)
       (abs (up - 1.0 - synth-cps-step) < 0.001) (abs (1.0 - synth-cps-step - down) < 0.001)
       (p1 = 1) (p2 = 0) (st 'over = 1)))

; --- the buffer's ex words: send plays its lines, cps sets, stop stops, and a word that
; --- is neither the engine's nor the loop's is still a complaint
(: st (synth-new ()) buf (vi-open "") _ (pin buf 'lines ["bd sn" "hh"])
   face (vi-face buf {'ex (synth-ex st)})
   (ex s) (: t (":" + s) (map (face 1) ((map (i \ t i) ^#t) + [13])))
   _ (ex "send") m1 (buf 'msg) on (st 'on) t (st 'lmsg)
   _ (ex "cps 1") m2 (buf 'msg) c (st 'cps)
   _ (ex "cps") m3 (buf 'msg)
   _ (ex "stop") m4 (buf 'msg) off (st 'on)
   _ (ex "play") m5 (buf 'msg) back (st 'on)
   _ (ex "zz") m6 (buf 'msg)
 (test (m1 = "sent") (on = 1) (t = "sent") (c = 1.0) (0 < #m2) (0 < #m3)
       (m4 = "stopped") (off = 0) (m5 = "playing") (back = 1)
       (m6 = "not an ex command: zz")))

; --- the text is read as harp reads it: a form's names are harp's even where the prel
; --- has one of the same name, and comment lines before the paren are passed over
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

(test_fin (),
 puts "synth: ok -- the keys bend as they should, the names are right, the turns stop, a strike rings, and the loop plays what the buffer says\n")
