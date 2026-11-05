; mixer -- the sounds a game's tics ask for, mixed into the horn: eight voices at most, the newest
; kept, each fading with distance and panned to the listener's ear.
;   (mix-cry st nm at)      sound nm queued in st 'sfx, from [x z] or () the listener's own; eight a frame
;   (mix-new hn sound ear o)  a feeder of (st) for view's 'song, writing a call the frames of st 'dt,
;                           the seconds since the last, so it keeps the clock at any frame rate,
;                           or a tic's where st has none:
;                           (sound nm) answers [samples rate], samples floats about 0, or () for none,
;                           (ear st) the listener [x z th], th radians from +z toward +x; o
;                           {'near 'far 'fps 'gain 'bus}: whole within near, gone past far; 'bus
;                           (st n), if given, answers n frames more to lay under them, (left . right)
;   (foot-next v sw)        which of six takes a foot makes next, v the last and sw the stride
;   (step-sound f v)        take v of a foot on feel f, a string: [samples rate]
(module (mixer mix-cry mix-new snd-noise snd-soft foot-next step-sound)
(borrow 'rove)
(borrow 'horn)                          ; song-rate
(:
 ; ..noise from a hash of each sample's time, about -1..1
 (snd-noise t) (: h (sin (t * 12345.678 + 0.5) * 43758.5453) (2.0 * (h - floor h) - 1.0))
 ; ..noise smoothed under hz, each hold joined to the next, no edge to buzz
 (snd-soft t hz) (: u (t * hz) i (floor u) f (u - i) a (snd-noise (i / hz)) (a + (snd-noise ((i + 1.0) / hz) - a) * f))
 ; ..never the last: the stride's own fraction shuffles it
 (foot-next v sw) ((v + 1 + int (5000.0 * sw) % 5) % 6)
 ; ..a foot on each feel, v which of six: no two alike in pitch, weight, length or grain. what
 ; gives underfoot rises gently and rolls heel to toe; what does not is struck
 step-rate 22050
 (step-sound f v) (: p ([1.0 1.09 0.93 1.05 0.97 1.13] v) g ([1.0 0.82 0.92 1.08 0.76 0.95] v) d ([0.1 0.125 0.085 0.14 0.11 0.095] v)
   T (0.26 + 0.02 * v) t (iota (int (T * step-rate)) / (1.0 * step-rate)) z (t + 3.7 * (v + 1))
   (o hz k) (sin (tau * hz * p * t) * exp -(k * t))
   (n k) (snd-noise z * exp -(k * t))
   (give u k) ((u > 0.0) * (1.0 - exp (-90.0 * (u * (u > 0.0)))) * exp -(k * (u * (u > 0.0))))
   (heel k) (give t k + 0.6 * give (t - d) k)
   (hush hz) (snd-soft z (hz * p))
   (grit hz) (: q (snd-soft (z + 1.3) hz) (0.35 + 1.6 * q * (q > 0.0)))
   thud (sin (tau * 62.0 * p * t) * give t 26.0)
   [(g * (f @ "grass" (0.2 * (0.6 * hush 3600.0 + 0.4 * hush 9000.0) * grit 110.0 * heel 24.0 + 0.03 * thud)
           "sand" (0.26 * (0.5 * hush 3400.0 + 0.5 * hush 10000.0) * grit 260.0 * heel 17.0 + 0.025 * thud)
           "gravel" (0.3 * (0.5 * hush 2400.0 + 0.5 * snd-noise z) * grit 420.0 * heel 26.0 + 0.07 * thud)
           "soft" (0.2 * o 70.0 30.0 + 0.05 * hush 900.0 * exp (-40.0 * t))
           "wood" (0.2 * o 150.0 42.0 + 0.1 * o 390.0 70.0 + 0.05 * n 130.0)
           "metal" (0.16 * o 110.0 42.0 + 0.07 * o 860.0 24.0 + 0.04 * o 1730.0 32.0 + 0.05 * n 140.0)
           (0.2 * o 120.0 55.0 + 0.09 * n 150.0)))
    step-rate])
 (mix-cry st nm at) (: q (st 'sfx) (#q < 8 && #nm > 0 ? (pin st 'sfx ([nm at] . q)) st))
 ; ..a voice started: [samples step at left right], the step the sound's rate over the horn's
 (voice S at E near far) (: dx (atom? at ? 0.0 (at 0 - E 0)) dz (atom? at ? 0.0 (at 1 - E 1)) d (sqrt (2 dx + 2 dz))
   v (d < near ? 1.0 (max 0.0 ((far - d) / (far - near))))
   p (d < 1.0 ? 0.5 (0.5 + 0.375 * (dx * cos (E 2) - dz * sin (E 2)) / d))
   (v <= 0.0 ? () [(S 0) (1.0 * S 1 / song-rate) 0 (v * (1.0 - p)) (v * p)]))
 (firsts l k) (k = 0 || atom? l ? () (<l . firsts >l (k - 1)))
 (mix-new hn sound ear o) (: box {'vs () 'carry 0.0} n0 (song-rate // peep o 'fps 35) pk (cite 'play 'pack)
   bus (o 'bus)
   near (1.0 * peep o 'near 1.0) far (1.0 * peep o 'far 10.0) g (1.0 * peep o 'gain 20000.0)
   (st \ (: dt (peep st 'dt ()) a (charm? dt || gem? dt ? (box 'carry + dt * song-rate) (1.0 * n0)) n (int a)
            _ (pin box 'carry (a - n)) z (iota n * 0.0)
            fx (st 'sfx) _ (pin st 'sfx ()) E (ear st)
            (start f) (sound (f 0) @ () () S (voice S (f 1) E near far))
            vs (firsts (filter two? (map start (rev fx)) + box 'vs) 8)
            (go l L R keep) (? (atom? l) [L R (rev keep)]
               (: v <l y (peep (v 0) (int ((iota n + v 2) * v 1)) 0.0) p (v 2 + n)
                  (go >l (L + y * v 3) (R + y * v 4) (p * v 1 < #(v 0) ? ([(v 0) (v 1) p (v 3) (v 4)] . keep) keep))))
            r (go vs z z ())
            m (bus ? (bus st n) ())
            (pin box 'vs (r 2), say hn (pk (two? m ? ((r 0 + <m) . (r 1 + >m)) (r 0 . r 1)) n g)))))
)) ; module mixer
