; test/host/ops.l -- the tones kernel (src/love/audio/tones.h) held to its arithmetic worked out
; here in love, each frame by its closed form: every operator feature alone, a graph run in three
; pieces with its outputs carried, a GENMIDI voice with feedback, and harp's kit sounding. close
; means within 1e-6, and within 1e-3 where an
; operator feeds back (its recurrence carries the two forms' last-bit differences on); a wave that
; jumps (quarter, tri, saw, square) may differ wholly at a frame on the jump, a rounding either side
;   cat test/00-init.l test/host/00-host.l test/host/ops.l | out/love
(borrow '(ops opl play bytes))
(: rate 12000.0 n 900
   ; --- the love form: an envelope's last segment begun, a wave, each operator a frame at a time ---
   (ops-t-seg ss t) (: (go l s) (? (atom? l) s (<l 0 <= t) (go >l <l) s) (go ss ()))
   (ops-t-env ss t) (ops-t-seg ss t @ () 0.0
     [t0 k a b c] (: u (t - t0) e (exp (0.0 - a * u)) d (exp (0.0 - b * u / ops-db))
                     v (k @ 0 (exp (0.0 - (a + b * u) / ops-db)) 1 (max 0.0 (a + b * u)) 2 ((1.0 - e) * d) _ ((1.0 - e) * (c + (1.0 - c) * d)))
                     (v < 1.5848931924611134e-05 ? 0.0 v)))
   (ops-t-wave w x ix du) (: u (x - floor x) s (sin (x * tau))
     (w @ 0 s 1 (max s 0.0) 2 (abs s) 3 (abs s * ((u >= 0.5 ? (u - 0.5) u) < 0.25 ? 1.0 0.0))
          4 (u < 0.5 ? (4.0 * u - 1.0) (3.0 - 4.0 * u)) 5 (2.0 * u - 1.0) 6 (u < du ? 1.0 -1.0) 8 (u < du ? 1.0 0.0)
          _ (: a ((ix * 1103515245 + 12345) & 4294967295) b (((a ^ (a >> 16)) * 2246822507) & 4294967295)
               c (((b ^ (b >> 13)) * 3266489909) & 4294967295) ((c >> 16 & 65535) * 0.000030517578125 - 1.0))))
   (ops-t-ref os st n f0 rate) (: k #os ys {} outs {} (y0 j q) (tray? st && #st = 2 * k ? (peep st (2 * j + q) 0.0) 0.0)
     (one j) (: o (os j) at (peep o 'at 0) f (peep o 'f 0.0) sl (peep o 'slide 0.0) g (peep o 'drop 0.0) ka (peep o 'kappa 0.0)
                w (peep o 'wave 0) m (peep o 'mod -1) q (peep o 'am -1) du (peep o 'duty 0.5) dep (peep o 'depth 0.0)
                fb (peep o 'fb 0.0 / 2.0) vib (peep o 'vib 0.0) vr (peep o 'vrate 0.0) tm (peep o 'trem 0.0) tr (peep o 'trate 0.0)
                lvl (peep o 'lvl 1.0) ss (peep o 'segs ())
                (go i y1 y2 acc) (? (i >= n) [(rev acc) y1 y2]
                  (f0 + i < at) (go (i + 1) y1 y2 (0.0 . acc))
                  (: t ((f0 + i - at) / (1.0 * rate))
                     a (ops-t-env ss t * lvl * (tm = 0.0 ? 1.0 (exp (0.0 - tm * (0.5 - 0.5 * cos (tr * t * tau)) / ops-db)))
                        * (q >= 0 && q < j ? (peep (outs q) i 0.0) 1.0))
                     x ((sl @ 0.0 (f * t) (f * (exp (sl * t) - 1.0) / sl)) + (g @ 0.0 0.0 (g * (1.0 - exp (0.0 - ka * t))))
                        + (vib = 0.0 || vr = 0.0 ? 0.0 (f * vib / (vr * tau) * (1.0 - cos (vr * t * tau))))
                        + (m >= 0 && m < j ? (dep * peep (outs m) i 0.0) 0.0) + fb * (y1 + y2))
                     v (a @ 0.0 0.0 (a * ops-t-wave w x (f0 + i) du))
                     (go (i + 1) v y1 (v . acc))))
                r (go 0 (y0 j 0) (y0 j 1) ())
                (pin outs j (gem-tray [n] (r 0)), pin ys j [(r 1) (r 2)]))
     _ (each ^k one)
     (side key) (: S (foldl (\ acc j (acc + outs j * peep (os j) key 0.0)) (iota n * 0.0) ^k) (map (i \ peep S i 0.0) ^n))
     (gem-tray [(2 * n + 2 * k)] (side 'l + side 'r + catmap ys ^k)))
   (ops-t-diff a b m) (peep a (iota m) 0.0 - peep b (iota m) 0.0)
   (ops-t-worst a b m) (: d (ops-t-diff a b m) (sqrt (amax (d * d))))
   (ops-t-off a b m eps) (net (map (i \ (: d (peep a i 0.0 - peep b i 0.0) (d * d > eps * eps ? 1 0))) ^m))
   (ops-t-pair os) [(ops-run (ops-rows os) os () n 0 rate ()) (ops-t-ref os () n 0 rate)]
   flat [[0.0 0 0.0 0.0 0.0]]
   ; every feature alone, and an FM pair: within 1e-6
   smooth [[{'f 220.0 'l 1.0 'segs flat}]
           [{'f 220.0 'vib 0.004 'vrate 6.1 'l 1.0 'segs flat}]
           [{'f 220.0 'trem 1.0 'trate 3.7 'l 1.0 'segs flat}]
           [{'f 220.0 'l 1.0 'segs [[0.0 1 0.0 50.0 0.0] [0.02 0 0.0 30.0 0.0] [0.05 0 0.9 0.0 0.0]]}]
           [{'f 220.0 'l 1.0 'segs [[0.0 2 420.0 20.0 0.0]]}]
           [{'f 220.0 'l 1.0 'segs [[0.0 3 420.0 9.0 0.5]]}]
           [{'f 110.0 'slide 0.7 'l 1.0 'segs flat}]
           [{'f 46.0 'drop 2.6 'kappa 34.0 'l 1.0 'segs flat}]
           [{'wave 7 'l 1.0 'segs flat}]
           [{'f 220.0 'wave 2 'l 1.0 'r 0.5 'segs flat}]
           [{'f 220.0 'lvl 0.5 'segs flat} {'f 440.0 'wave 1 'mod 0 'depth 2.0 'l 1.0 'r 0.3 'segs flat}]
           [{'at 300 'f 220.0 'l 1.0 'segs [[0.0 0 0.0 0.0 0.0] [0.01 1 0.0 0.0 0.0]]}]
           ; ..a level multiplied by another operator's output
           [{'f 7.0 'segs flat} {'f 440.0 'am 0 'l 1.0 'r 0.4 'segs flat}]]
   _ (test (all (os \ (: p (ops-t-pair os) (ops-t-worst (p 0) (p 1) (2 * n) < 1e-6))) smooth))
   ; ..fed back: within 1e-3
   _ (test (: p (ops-t-pair [{'f 220.0 'fb 0.5 'l 1.0 'segs flat}]) (ops-t-worst (p 0) (p 1) (2 * n) < 1e-3)))
   ; ..the jumping waves: off by more than 1e-6 at under 1% of frames
   _ (test (all (w \ (: p (ops-t-pair [{'f 230.0 'wave w 'l 1.0 'segs flat}]) (ops-t-off (p 0) (p 1) n 1e-6 < n // 100))) [3 4 5 6 8])
           (: p (ops-t-pair [{'f 230.0 'wave 6 'duty 0.3 'l 1.0 'segs flat}]) (ops-t-off (p 0) (p 1) n 1e-6 < n // 100))
           ; ..noise its level a pulse a fifth of its turn high: the clap's chatter
           (: p (ops-t-pair [{'f 220.0 'wave 8 'duty 0.2 'segs flat} {'wave 7 'am 0 'l 1.0 'r 0.4 'segs flat}])
              (ops-t-off (p 0) (p 1) (2 * n) 1e-6 < n // 50)))
   ; a graph in three runs of n, each operator's last two outputs carried, against the love form so
   os [{'at 100 'f 220.0 'fb 0.5 'lvl 0.5 'vib 0.004 'vrate 6.1 'segs [[0.0 1 0.0 50.0 0.0] [0.02 0 0.0 30.0 0.0]]}
       {'at 100 'f 440.0 'wave 1 'mod 0 'depth 2.0 'l 0.7 'r 0.3 'trem 1.0 'trate 3.7 'segs [[0.0 2 420.0 20.0 0.0]]}
       {'at 300 'f 110.0 'slide 0.7 'wave 0 'l 0.2 'r 0.2 'segs [[0.0 3 420.0 9.0 0.5] [0.3 1 0.0 0.0 0.0]]}]
   R (ops-rows os) k #os
   (three f) (: (go j st acc) (j = 3 ? acc (: r (f st (j * n)) (go (j + 1) (peep r (iota (2 * k) + 2 * n) 0.0) (acc + [r])))) (go 0 () ()))
   K (three (\ st f0 (ops-run R os st n f0 rate ()))) F (three (\ st f0 (ops-t-ref os st n f0 rate)))
   _ (test (all (j \ ops-t-worst (K j) (F j) (2 * n + 2 * k) < 1e-3) ^3) (0.1 < sqrt (amax (K 2 * K 2))))
   ; ..and with the scratch in a workspace kept across the runs, the same answer to the bit, less it
   ws ((cite 'dsp 'tones-ws) (k * n)) W (three (\ st f0 (ops-run R os st n f0 rate ws)))
   _ (test (all (j \ #(W j) = 2 * n + 2 * k && aall (W j = peep (K j) (iota (2 * n + 2 * k)) 0.0)) ^3))
   ; a GENMIDI voice fed back, its modulator into its carrier, held then let go, three runs carried
   (ops-t-b l) (foldl (\ a c (a + string c)) "" l)
   v (ops-t-b [33 241 36 0 64 20 10 33 242 18 0 0 0 0 0 0])
   B (opl-bank ("#OPL_II#" + ops-t-b [0 0 128 0] + v + v + zbytes (174 * 36) + "fm" + zbytes (30 + 174 * 32)))
   g (opl-ops (B 0) 60 100 0.5 0 1500 12000) os2 (g 0) R2 (ops-rows os2) k2 #os2
   (three2 f) (: (go j st acc) (j = 3 ? acc (: r (f st (j * n)) (go (j + 1) (peep r (iota (2 * k2) + 2 * n) 0.0) (acc + [r])))) (go 0 () ()))
   K2 (three2 (\ st f0 (ops-run R2 os2 st n f0 rate ()))) F2 (three2 (\ st f0 (ops-t-ref os2 st n f0 rate)))
   _ (test (all (j \ ops-t-worst (K2 j) (F2 j) (2 * n + 2 * k2) < 1e-3) ^3) (0.05 < sqrt (amax (K2 0 * K2 0))) (g 1 > 1500))
   ; harp's kit on the kernel: a chime, a box gliding, a kick, a snare, a clap and a short triangle sound
   (kv v) (mkvoice 10 v 12000)
   kit [{'s "chime" 'note 4} {'s "box" 'note 0 'slide 7} {'s "bd"} {'s "sn"} {'s "cp"} {'s "tri" 'note -12 'legato 0.05}]
   _ (test (all (x \ (: a (kv x) y ((a 1) (iota 1800)) (two? a && 0.01 < sqrt (amax (y * y))))) kit))
   ; tones-mix against the pieces mixall sums and pack lays, chunk by chunk to the byte: a box by
   ; its twin, a chime echoed past its end, a drone looped every 2900 frames, and a wind's closure
   tmx (cite 'dsp 'tones-mix) tlp (cite 'dsp 'tones-loop) mxa (cite 'dsp 'mixall)
   (mv v at) (mkvoice at v 12000)
   a1 (mv {'s "box" 'note 3 'gain 0.6 'pan 0.3} 50)
   e1 (echoed (mv {'s "chime" 'note -5 'gain 0.5 'legato 0.3} 400) [[700 0.45] [1900 0.2]])
   d0 (ops-voice [{'f 110.0 'trem 3.0 'trate 0.4 'vib 0.002 'vrate 0.3 'segs [[0.0 1 1.0 0.0 0.0]]}] 0 100000000 1.0 1.0 12000)
   (lp ix) (ix % 2900)
   d1 [(d0 0) (ix \ d0 1 (lp ix)) 0.4 0.4 (ix \ d0 4 (lp ix)) (tlp (d0 5) 2900)]
   w1 (mv {'s "wind" 'note -12 'gain 0.3 'legato 2.0} 200)
   mws ((cite 'dsp 'tones-ws) (14 * 4096))
   (lr2 m) ((peep m (iota 1000) 0.0) . (peep m (iota 1000 + 1000) 0.0))
   (chunk c) (: base (c * 1000) ix (iota 1000 + base) wy (w1 1 ix)
      lv ([[(a1 4 ix) (a1 2) (a1 3) 0]] + map (p \ [(p 0) (e1 2 * p 2) (e1 3 * p 2) (p 1)]) (e1 5 ix)
          + [[(d1 4 ix) (d1 2) (d1 3) 0] [wy (w1 2) (w1 3) 0]])
      cv [[(a1 5) (a1 2) (a1 3)] [(e1 6) (e1 2) (e1 3)] [(d1 5) (d1 2) (d1 3)] [wy (w1 2) (w1 3) 0]]
      bl (pack (lr2 (mxa lv 1000)) 1000 9000.0) bc (tmx cv base 1000 9000.0 mws)
      (string? bc && bl = bc && any (i \ bc i != 0) ^4000))
   _ (test (#a1 = 6 && #e1 = 7 && ?(e1 6) && ?(d1 5) && #w1 = 4) (all chunk ^12))
   ((test_fin ()),
    puts "ops: ok\n"))
