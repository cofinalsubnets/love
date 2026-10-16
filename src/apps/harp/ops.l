; ops -- voices as small graphs of operators for the tones kernel (src/love/audio/tones.c): an
; operator's row laid from a tablet, a voice in play's shape, and the kernel's arithmetic again in
; love, closed forms a frame at a time, to hold the kernel to.
;   (ops-row o)        an operator's 49 numbers from a tablet: 'f 'slide 'drop 'kappa 'wave 'mod
;                      'depth 'fb 'l 'r 'vib 'vrate 'trem 'trate 'lvl, 'segs [[t0 kind a b c] ..],
;                      'at the frame its voice starts; what is missing 0, 'mod -1, 'lvl 1
;   (ops-rows os)      the operators' rows, one float tray
;   (ops-run R os st n f0 rate)  the kernel over rows R (of operators os) for n frames from f0,
;                      st their last two outputs each (() at rest): n of left then n of right,
;                      each operator's last two outputs, then scratch
;   (ops-ref os st n f0 rate)  the same answer worked out in love, no scratch
;   (ops-voice os at end gl gr rate)  play's voice [end fn gl gr], fn the left the operators
;                      sum to, their outputs fed back from one run to the next; worked out in
;                      love where the first operator has 'ref 1
(module (ops ops-row ops-rows ops-run ops-ref ops-voice ops-db)
(:
 width 49
 ops-db 8.685889638065035                ; dB a neper: 20 / ln 10
 (ops-row o) (: (g k d) (peep o k d) ss (peep o 'segs ())
   ([(1.0 * g 'at 0) (1.0 * g 'f 0) (1.0 * g 'slide 0) (1.0 * g 'drop 0) (1.0 * g 'kappa 0) (1.0 * g 'wave 0)
    (1.0 * g 'mod -1) (1.0 * g 'depth 0) (1.0 * g 'fb 0) (1.0 * g 'l 0) (1.0 * g 'r 0) (1.0 * g 'vib 0)
    (1.0 * g 'vrate 0) (1.0 * g 'trem 0) (1.0 * g 'trate 0) 0.0 0.0 (1.0 * g 'lvl 1)
    (1.0 * #ss)] + cats (map (s \ map (x \ 1.0 * x) s) ss) + map (_ \ 0.0) ^(5 * (6 - #ss))))
 (ops-rows os) (gem-tray [(width * #os)] (cats (map ops-row os)))
 kern (cite 'dsp 'tones)
 ; ..the reference where the seat has no kernel, or the first operator asks for it ('ref 1)
 (ops-run R os st n f0 rate) (kern && !(peep <os 'ref 0) ? (kern R st n f0 rate) (ops-ref os st n f0 rate))

 ; --- the reference: each frame by its closed form ---
 (seg-of ss t) (: (go l s) (? (atom? l) s (<l 0 <= t) (go >l <l) s) (go ss ()))
 (env ss t) (seg-of ss t @ () 0.0
   [t0 k a b c] (: u (t - t0) e (exp (0.0 - a * u)) d (exp (0.0 - b * u / ops-db))
                   v (k @ 0 (exp (0.0 - (a + b * u) / ops-db)) 1 (max2 0.0 (a + b * u)) 2 ((1.0 - e) * d) _ ((1.0 - e) * (c + (1.0 - c) * d)))
                   (v < 1.5848931924611134e-05 ? 0.0 v)))
 (wave w x ix) (: u (x - floor x) s (sin (x * tau))
   (w @ 0 s 1 (max2 s 0.0) 2 (abs s) 3 (abs s * ((u >= 0.5 ? (u - 0.5) u) < 0.25 ? 1.0 0.0))
        4 (u < 0.5 ? (4.0 * u - 1.0) (3.0 - 4.0 * u)) 5 (2.0 * u - 1.0) 6 (u < 0.5 ? 1.0 -1.0)
        _ (: a ((ix * 1103515245 + 12345) & 4294967295) b (((a ^ (a >> 16)) * 2246822507) & 4294967295)
             c (((b ^ (b >> 13)) * 3266489909) & 4294967295) ((c >> 16 & 65535) * 0.000030517578125 - 1.0))))
 (ops-ref os st n f0 rate) (: k #os ys {} outs {} (y0 j q) (tray? st && #st = 2 * k ? (peep st (2 * j + q) 0.0) 0.0)
   (one j) (: o (os j) at (peep o 'at 0) f (peep o 'f 0.0) sl (peep o 'slide 0.0) g (peep o 'drop 0.0) ka (peep o 'kappa 0.0)
              w (peep o 'wave 0) m (peep o 'mod -1) dep (peep o 'depth 0.0) fb (peep o 'fb 0.0 / 2.0) vib (peep o 'vib 0.0)
              vr (peep o 'vrate 0.0) tm (peep o 'trem 0.0) tr (peep o 'trate 0.0) lvl (peep o 'lvl 1.0) ss (peep o 'segs ())
              (go i y1 y2 acc) (? (i >= n) [(rev acc) y1 y2]
                (f0 + i < at) (go (i + 1) y1 y2 (0.0 . acc))
                (: t ((f0 + i - at) / (1.0 * rate))
                   a (env ss t * lvl * (tm = 0.0 ? 1.0 (exp (0.0 - tm * (0.5 - 0.5 * cos (tr * t * tau)) / ops-db))))
                   x ((sl = 0.0 ? (f * t) (f * (exp (sl * t) - 1.0) / sl)) + (g = 0.0 ? 0.0 (g * (1.0 - exp (0.0 - ka * t))))
                      + (vib = 0.0 || vr = 0.0 ? 0.0 (f * vib / (vr * tau) * (1.0 - cos (vr * t * tau))))
                      + (m >= 0 && m < j ? (dep * peep (outs m) i 0.0) 0.0) + fb * (y1 + y2))
                   v (a = 0.0 ? 0.0 (a * wave w x (f0 + i)))
                   (go (i + 1) v y1 (v . acc))))
              r (go 0 (y0 j 0) (y0 j 1) ())
              (pin outs j (gem-tray [n] (r 0)), pin ys j [(r 1) (r 2)]))
   _ (each ^k one)
   (side key) (: S (foldl (\ acc j (acc + outs j * peep (os j) key 0.0)) (iota n * 0.0) ^k) (map (i \ peep S i 0.0) ^n))
   (gem-tray [(2 * n + 2 * k)] (side 'l + side 'r + cats (map (j \ ys j) ^k))))

 ; --- a voice: the kernel run for the frames asked, the outputs carried; asked for frames out
 ;     of their order (a law's look), it runs again from the start to reach them ---
 (ops-voice os at end gl gr rate) (: k #os os0 (map (o \ pin o 'at at) os) R (ops-rows os0) box {'next at 'ys ()}
   S (iota (2 * k) + 0)
   (run f0 n) (: r (ops-run R os0 (box 'ys) n f0 rate) (pins box 'next (f0 + n) 'ys (peep r (S + 2 * n) 0.0), r))
   (reach f0) (? (f0 = box 'next) 0
                 (f0 <= at) (pins box 'next f0 'ys ())
                 (: _ (pins box 'next at 'ys ())
                    (go p) (p >= f0 ? 0 (: _ (run p (min2 4096 (f0 - p))) (go (box 'next))))
                    (go at)))
   fn (ix \ (: n #ix f0 (peep ix 0 0) _ (reach f0) r (run f0 n) (peep r (iota n) 0.0)))
   [end fn gl gr])
 (max2 a b) (a < b ? b a)
 (min2 a b) (a < b ? a b)
)) ; module ops
