; test/host/ops.l -- the tones kernel (src/love/audio/tones.c) held to ops.l's love form, frame by
; frame: every operator feature alone, a graph run in three pieces with its outputs carried, a
; GENMIDI voice with feedback, and harp's kit. close means within 1e-6, and within 1e-3 where an
; operator feeds back (its recurrence carries the two forms' last-bit differences on); a wave that
; jumps (quarter, tri, saw, square) may differ wholly at a frame on the jump, a rounding either side
;   cat test/00-init.l test/host/00-host.l test/host/ops.l | out/love
(borrow 'ops)
(borrow 'opl)
(borrow 'play)
(borrow 'bytes)
(: rate 12000.0 n 900
   (ops-t-diff a b m) (peep a (iota m) 0.0 - peep b (iota m) 0.0)
   (ops-t-worst a b m) (: d (ops-t-diff a b m) (sqrt (amax (d * d))))
   (ops-t-off a b m eps) (net (map (i \ (: d (peep a i 0.0 - peep b i 0.0) (d * d > eps * eps ? 1 0))) ^m))
   (ops-t-pair os) [(ops-run (ops-rows os) os () n 0 rate) (ops-ref os () n 0 rate)]
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
           [{'at 300 'f 220.0 'l 1.0 'segs [[0.0 0 0.0 0.0 0.0] [0.01 1 0.0 0.0 0.0]]}]]
   _ (test (all (os \ (: p (ops-t-pair os) (ops-t-worst (p 0) (p 1) (2 * n) < 1e-6))) smooth))
   ; ..fed back: within 1e-3
   _ (test (: p (ops-t-pair [{'f 220.0 'fb 0.5 'l 1.0 'segs flat}]) (ops-t-worst (p 0) (p 1) (2 * n) < 1e-3)))
   ; ..the jumping waves: off by more than 1e-6 at under 1% of frames
   _ (test (all (w \ (: p (ops-t-pair [{'f 230.0 'wave w 'l 1.0 'segs flat}]) (ops-t-off (p 0) (p 1) n 1e-6 < n // 100))) [3 4 5 6]))
   ; a graph in three runs of n, each operator's last two outputs carried, against the love form so
   os [{'at 100 'f 220.0 'fb 0.5 'lvl 0.5 'vib 0.004 'vrate 6.1 'segs [[0.0 1 0.0 50.0 0.0] [0.02 0 0.0 30.0 0.0]]}
       {'at 100 'f 440.0 'wave 1 'mod 0 'depth 2.0 'l 0.7 'r 0.3 'trem 1.0 'trate 3.7 'segs [[0.0 2 420.0 20.0 0.0]]}
       {'at 300 'f 110.0 'slide 0.7 'wave 0 'l 0.2 'r 0.2 'segs [[0.0 3 420.0 9.0 0.5] [0.3 1 0.0 0.0 0.0]]}]
   R (ops-rows os) k #os
   (three f) (: (go j st acc) (j = 3 ? acc (: r (f st (j * n)) (go (j + 1) (peep r (iota (2 * k) + 2 * n) 0.0) (acc + [r])))) (go 0 () ()))
   K (three (\ st f0 (ops-run R os st n f0 rate))) F (three (\ st f0 (ops-ref os st n f0 rate)))
   _ (test (all (j \ ops-t-worst (K j) (F j) (2 * n + 2 * k) < 1e-3) ^3) (0.1 < sqrt (amax (K 2 * K 2))))
   ; a GENMIDI voice fed back, its modulator into its carrier, held then let go, as play's voice
   ;   both ways: the kernel's and the love form's ('ref on its first operator)
   (ops-t-b l) (foldl (\ a c (a + string c)) "" l)
   v (ops-t-b [33 241 36 0 64 20 10 33 242 18 0 0 0 0 0 0])
   B (opl-bank ("#OPL_II#" + ops-t-b [0 0 128 0] + v + v + zbytes (174 * 36) + "fm" + zbytes (30 + 174 * 32)))
   ; ..each side its own operators: a voice pins its start on them
   g (opl-ops (B 0) 60 100 0.5 0 1500 12000) h (opl-ops (B 0) 60 100 0.5 0 1500 12000)
   _ (pin <(h 0) 'ref 1)
   va (ops-voice (g 0) 0 (g 1) 0.5 0.5 12000) vr (ops-voice (h 0) 0 (h 1) 0.5 0.5 12000)
   ya ((va 1) (iota 2400)) yr ((vr 1) (iota 2400))
   _ (test (sqrt (amax ((ya - yr) * (ya - yr))) < 1e-3) (0.05 < sqrt (amax (ya * ya))) (g 1 > 1500))
   ; harp's kit on the kernel: a chime, a box gliding, a kick, a snare and a short triangle sound
   (kv v) (mkvoice 10 v 12000)
   kit [{'s "chime" 'note 4} {'s "box" 'note 0 'slide 7} {'s "bd"} {'s "sn"} {'s "tri" 'note -12 'legato 0.05}]
   _ (test (all (x \ (: a (kv x) y ((a 1) (iota 1800)) (two? a && 0.01 < sqrt (amax (y * y))))) kit))
   ((test_fin ()),
    puts "ops: ok\n"))
