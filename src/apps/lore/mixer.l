; mixer -- the sounds a game's tics ask for, mixed into the horn: eight voices at most, the newest
; kept, each fading with distance and panned to the listener's ear.
;   (mix-cry st nm at)      sound nm queued in st 'sfx, from [x z] or () the listener's own; eight a frame
;   (mix-new hn sound ear o)  a feeder of (st) for view's 'song, writing a tic's frames a call:
;                           (sound nm) answers [samples rate], samples floats about 0, or () for none,
;                           (ear st) the listener [x z th], th radians from +z toward +x; o
;                           {'near 'far 'fps 'gain 'bus}: whole within near, gone past far; 'bus
;                           (st n), if given, answers n frames more to lay under them, (left . right)
(module (mixer mix-cry mix-new)
(borrow 'rove)                          ; song-rate
(borrow 'view)                          ; max2
(:
 (mix-cry st nm at) (: q (peep st 'sfx ()) (#q < 8 && #nm > 0 ? (pin st 'sfx ([nm at] . q)) st))
 ; ..a voice started: [samples step at left right], the step the sound's rate over the horn's
 (voice S at E near far) (: dx (atom? at ? 0.0 (at 0 - E 0)) dz (atom? at ? 0.0 (at 1 - E 1)) d (sqrt (dx * dx + dz * dz))
   v (d < near ? 1.0 (max2 0.0 ((far - d) / (far - near))))
   p (d < 1.0 ? 0.5 (0.5 + 0.375 * (dx * cos (E 2) - dz * sin (E 2)) / d))
   (v <= 0.0 ? () [(S 0) (1.0 * S 1 / song-rate) 0 (v * (1.0 - p)) (v * p)]))
 (firsts l k) (k = 0 || atom? l ? () (<l . firsts >l (k - 1)))
 (mix-new hn sound ear o) (: box {'vs ()} n (song-rate // peep o 'fps 35) pk (cite 'play 'pack) z (iota n * 0.0)
   bus (peep o 'bus ())
   near (1.0 * peep o 'near 1.0) far (1.0 * peep o 'far 10.0) g (1.0 * peep o 'gain 20000.0)
   (st \ (: fx (peep st 'sfx ()) _ (pin st 'sfx ()) E (ear st)
            (start f) (sound (f 0) @ () () S (voice S (f 1) E near far))
            vs (firsts (filter two? (map start (rev fx)) + box 'vs) 8)
            (go l L R keep) (? (atom? l) [L R (rev keep)]
               (: v <l y (peep (v 0) (int ((iota n + v 2) * v 1)) 0.0) p (v 2 + n)
                  (go >l (L + y * v 3) (R + y * v 4) (p * v 1 < #(v 0) ? ([(v 0) (v 1) p (v 3) (v 4)] . keep) keep))))
            r (go vs z z ())
            m (bus ? (bus st n) ())
            (pin box 'vs (r 2), say hn (pk (two? m ? ((r 0 + <m) . (r 1 + >m)) (r 0 . r 1)) n g)))))
)) ; module mixer
