; src/apps/player/bus.l -- the player core's mix bus: the eq, volume and balance over s16 pcm,
; and the views' feeds off what comes out. eq.c's biquads and spectrum do the per-sample work;
; numbers cross to it in Q40, laid here. `(borrow 'bus)`, then:
;
;   bus-bands               winamp's ten centers, Hz
;   (bus-co rate eq pre vol bal on) -> the coefficients for biquads: each band an rbj peaking
;                           filter (sox's equalizer, width in q), a 0 dB band left out, a band
;                           past nyquist too; preamp, volume (0..100) and balance (-100..100)
;                           as the two channels' gains
;   (bus-run b pcm ch)      -> pcm through b, a bus tablet ('co, 'st) whose memory moves on
;   (bus-new)               -> a bus at rest, flat
;   (bus-spec pcm ch rate n) -> n bins 0..255, log-spaced 20 Hz .. 20 kHz, dB -96 .. 0 of full
;                           scale, off the last 2048 frames of pcm
;   (bus-scope pcm ch n)    -> n columns [lo hi] of pcm's left (or only) channel, -128..127
(module (bus bus-bands bus-q bus-co bus-new bus-run bus-spec bus-scope bus-q40 bus-edges bus-tw)
(:
   peepv (cite 'guts 'peepv) pinv (cite 'guts 'pinv)
   bus-q40 1099511627776.0
   bus-bands [60 170 310 600 1000 3000 6000 12000 14000 16000]
   bus-width 1.41                        ; q: about an octave a band
   pi 3.141592653589793
   ; floats as Q40 int64s, one string
   (bus-q l) (: c (cask (8 * #l))
                (each ^#l (i \ pinv c (8 * i) 8 8 (iota 1 + (l i) * bus-q40)),
                 string c))
   (db g) (10.0 ** (g / 20.0))
   ; rbj's peaking eq, a0 divided out
   (peak rate f g)
    (: A (10.0 ** (g / 40.0)) w (2.0 * pi * f / rate) al (sin w / (2.0 * bus-width))
       cw (cos w) a0 (1.0 + al / A)
       [((1.0 + al * A) / a0) (-2.0 * cw / a0) ((1.0 - al * A) / a0) (-2.0 * cw / a0) ((1.0 - al / A) / a0)])
   (bus-co rate eq pre vol bal on)
    (: v (vol / 100.0 * (on ? (db pre) 1.0))
       gl (v * (bal > 0 ? (1.0 - bal / 100.0) 1.0)) gr (v * (bal < 0 ? (1.0 + bal / 100.0) 1.0))
       bs (? !on ()
             (foldl (\ a i (? ((eq i) = 0 || bus-bands i * 2 >= rate) a (a + peak rate (bus-bands i) (eq i))))
                    () ^10))
       (bus-q ([gl gr] + bs)))
   (bus-new _) {'co (bus-co 44100 (map (_ \ 0) ^10) 0 100 0 1) 'st ""}
   (bus-run b pcm ch)
    ((cite 'dsp 'biquads) pcm ch (b 'co) (b 'st) @
      (out . st) (pin b 'st st, out)
      why pcm)

   ; --- the feeds -------------------------------------------------------------
   bus-n 2048
   ; the window, then the twiddles e^(-2 pi i k / n) as cosines and sines, made once
   (bus-tw n) (: t (iota n) h (iota (n // 2)) a (2.0 * pi / n)
                 c (cask (16 * n))
                 (pinv c 0 8 8 ((0.5 - 0.5 * cos (a * t)) * bus-q40),
                  pinv c (8 * n) 8 8 (cos (a * h) * bus-q40),
                  pinv c (12 * n) 8 8 (sin (a * h) * bus-q40),
                  string c))
   tws {}
   (tw n) (peep tws n () || (pin tws n (bus-tw n), tws n))
   ; u16 fft bins bounding n log-spaced bands, 20 Hz .. 20 kHz
   (bus-edges rate n)
    (: c (cask (2 * (n + 1))) top (bus-n // 2)
       (each ^(n + 1) (i \ pinv c (2 * i) 2 2
                          (iota 1 + min top (int (20.0 * (1000.0 ** (i / n)) * bus-n / rate + 0.5)))),
        string c))
   edges {}
   (edge rate n) (: k [rate n] (peep edges k () || (pin edges k (bus-edges rate n), edges k)))
   ; a full-scale sine's peak bin under the hann window: (32767 n / 4) squared
   ref (: a (32767.0 * bus-n / 4.0) (a * a))
   (bus-spec pcm ch rate n)
    ((cite 'dsp 'spectrum) pcm ch (tw bus-n) (edge rate n) @
      s (string? s ? (: c (cask #s) _ (pour c 0 s 0 #s)
                        p (peepv c 0 8 8 n)
                        v (max 0 (min 255 (int ((10.0 * log ((p + 1) / ref) / log 10.0 + 96.0) * 255.0 / 96.0))))
                        (map (i \ peep v i 0) ^n))
           (map (_ \ 0) ^n)))
   (bus-scope pcm ch n)
    (: f (#pcm // (2 * ch)) c (cask #pcm) _ (pour c 0 pcm 0 #pcm)
       (col i) (: a (i * f // n) b (max (a + 1) ((i + 1) * f // n))
                  t (peepv c (2 * ch * a) 2 (2 * ch) (b - a))
                  s (t - 65536 * (t >= 32768))
                  [((amin s) >> 8) ((amax s) >> 8)])
       (f < n ? (map (_ \ [0 0]) ^n) (map col ^n))))
) ; module bus
