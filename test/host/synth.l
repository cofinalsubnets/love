; --- test/host/synth.l: the keyboard synth, headless ---
; not in the test/*.l corpus (it loads a crew module). the keys, the notes and the feed
; are pure, so everything but the tty runner gates here: a key into a degree and its
; bends, the bends' sizes against each other, a note's name, the timbre and octave
; turned and bounded, and a strike ringing into a jug.
;   cat test/00-init.l test/host/synth.l | out/love

(borrow 'synth)   ; the artifact's module, warm from the tree

(: (find h n i) (i + #n < 1 + #h ? (n = snip h i (i + #n) ? 1 (find h n (i + 1))) 0)
   (has? h n) (find h n 0)
   d0 (synth-digits 0) d1 (synth-digits 1) s0 (synth-shifted 0)
   st (synth-new ())
   (semis c) (synth-semis st c))

; --- a key: a digit is a degree, its shifted mate the same with shift, 256 past either
; --- is alt, and any other key is nothing
(test (synth-code d0 = [0 0 0]) (synth-code d1 = [1 0 0]) (synth-code (synth-digits 9) = [9 0 0])
      (synth-code s0 = [0 1 0]) (synth-code (256 + d0) = [0 0 1]) (synth-code (256 + s0) = [0 1 1])
      (synth-code 97 = ()) (synth-code 9 = ()) (synth-code -8 = ()))

; --- the bends against each other: a key on is a whole tone, shift half of that, alt
; --- half of shift and down, both together up by what alt took
(: a (semis [0 0 0]) b (semis [1 0 0]) sh (semis [0 1 0]) al (semis [0 0 1]) bo (semis [0 1 1])
 (test (abs (b - a - 2.0) < 0.001) (abs (sh - a - 1.0) < 0.001)
       (abs (a - al - 0.5) < 0.001) (abs (bo - a - 0.5) < 0.001)
       (abs (semis [5 0 0] - a - 10.0) < 0.001)))

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

(test_fin (),
 puts "synth: ok -- the keys bend as they should, the names are right, the turns stop, and a strike rings\n")
