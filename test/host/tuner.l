; test/host/tuner.l -- the tuner (src/apps/tuner.l); the clock is the test's own, so the hold needs no waiting
;   cat test/00-init.l test/host/tuner.l | out/love
(borrow 'tuner)
(: (cents-off f g) (gem? f ? (abs (1200.0 * log (f / g) / log 2.0)) 1e9)
   (heard f) (tuner-yin (tuner-sine f))
   quiet (tuner-sine 440.0 * 0.0)
   ; the ear: within a cent from a bass's low B to A6, nothing in silence
   _ (test (cents-off (heard 440.0) 440.0 < 1.0) (cents-off (heard 82.41) 82.41 < 1.0)
           (cents-off (heard 61.74) 61.74 < 1.0) (cents-off (heard 261.63) 261.63 < 1.0)
           (cents-off (heard 1760.0) 1760.0 < 1.0) !(tuner-yin quiet))
   ; a row is an eighth tone, cents over midi 0 by 25: A4 is 276, C4 240
   _ (test (["A" 4 0] = tuner-note 276) (["C" 4 0] = tuner-note 240) (["C" 4 1] = tuner-note 241)
           (["B" 3 3] = tuner-note 239) (["C" 0 0] = tuner-note 48) (["A♯" 4 2] = tuner-note 282)
           (6900.0 = tuner-cents 440.0 440.0) (abs (tuner-cents 442.0 440.0 - 6892.15) < 0.01))
   ; a frame at 445: the marker an eighth over A4, the needle right of centre
   clk {'now 0}
   (fresh _) (pins (tuner-new 440.0 "law") 'clock (_ \ clk 'now) 'sp 0)     ; the scale alone
   t (fresh ())
   _ (tuner-hear t (tuner-sine 445.0))
   fr (tuner-frame t 80 30)
   rs (map tuner-plain fr)
   (line x i) (tuner-plain (tuner-frame x 80 30 i))     ; row i of x's frame, as the screen shows it
   _ (test (30 = #rs) (has? (rs 14) "◀━━ A4  +20¢  445.0 Hz") (has? (rs 15) "A4   ━━━━━━┫")
           (has? (rs 11) "A♯4") (has? (rs 7) "B4") (has? (rs 3) "C5") (has? (rs 13) "╺━━━┃ ¼")
           (has? (fr 15) "38;5;41") (has? (fr 3) "38;5;45")
           (: n (rs 27) c (fsub n "┃" 0) d (fsub n "●" 0) (0 < c && c < d)))
   ; the reading moves part way to a nearby pitch and takes a new note whole
   c0 (t 'c)
   _ (tuner-hear t (tuner-sine 447.0))
   c1 (t 'c)
   _ (tuner-hear t (tuner-sine 660.0))
   _ (test (c0 < c1) (c1 < tuner-cents 440.0 447.0) (abs (t 'c - tuner-cents 440.0 660.0) < 1.0))
   ; the range: 440 then 452 is one note spanning +0..+47 cents, three eighths solid
   g (fresh ())
   _ (tuner-hear g (tuner-sine 440.0))
   _ (tuner-hear g (tuner-sine 452.0))
   gs (map tuner-plain (tuner-frame g 80 30))
   _ (test (has? (gs 14) "+0…+47¢") (has? (gs 13) "█") (has? (gs 14) "█") (has? (gs 15) "█")
           !(has? (gs 12) "█") !(has? (gs 16) "█") (has? (gs 27) "━"))
   ; the hold: a silence keeps the reading faint for 2.5 s; a pitch after is a new note
   _ (pin clk 'now 1000)
   _ (tuner-hear g (tuner-sine 440.0 * 0.0))
   hs (map tuner-plain (tuner-frame g 80 30))
   faint? (r \ has? r "\e[2;38;5;")                  ; the hold's pen
   _ (test !(g 'c) (faint? (tuner-frame g 80 30 14)) (has? (hs 14) "+0…+47¢") !(has? (hs 14) "held")
           !(has? (hs 27) "listening"))
   _ (pin clk 'now 2400)
   _ (test (has? (line g 14) "◀") (faint? (tuner-frame g 80 30 14)))
   _ (pin clk 'now 2501)
   _ (test (has? (line g 27) "(listening)")
           !(has? (line g 14) "◀"))
   _ (tuner-hear g (tuner-sine 445.0))
   ns (line g 14)
   _ (test (g 'lo = g 'hi) (has? ns "◀━━ A4  +20¢  445.0 Hz") !(has? ns "…") !(faint? (tuner-frame g 80 30 14)))
   ; the needle: a wobble of 440/446 Hz holds it still between them; a steady change arrives
   j (fresh ())
   (cell x) (: _ (tuner-frame x 80 30) <>(x 'ncell))
   (feed f k acc) (k = 0 ? (rev acc) (: _ (tuner-hear j (tuner-sine (f k))) (feed f (k - 1) (cell j . acc))))
   wob (drop 8 (feed (k \ k % 2 = 0 ? 440.0 446.0) 16 ()))
   held (feed (_ \ 452.0) 16 ())
   _ (test (last (sort wob) - <(sort wob) <= 1) (abs (<wob - 47) <= 1) (abs (last held - 73) <= 1))
   ; the spectrum: A3 plus E5 peak clear over a floor under -60 dBFS; silence falls 3 dB a
   ; window; s hides it, and a short screen goes without
   s (pin (fresh ()) 'sp 1)
   _ (tuner-hear s (tuner-sine 220.0 + tuner-sine 660.0 * 0.3))
   sp (s 'spec)
   ss (map tuner-plain (tuner-frame s 80 30))
   pk (sp 33)
   _ (test (84 = #sp) (pk = foldl max -999.0 sp) (-14.0 < pk < -10.0) (sp 52 > -30.0)
           (sp 51 < sp 52) (sp 53 < sp 52) (sp 10 < -60.0)
           (30 = #ss) (has? (ss 27) "C1") (has? (ss 27) "C7") (has? (ss 26) "█")
           (has? (ss 21) "●") (has? (tuner-frame s 80 30 26) "1;38;5;148m█"))
   ; a tall screen stands the spectrum beside the scale, nothing past its edge
   vf (tuner-frame s 45 43)
   vs (map tuner-plain vf)
   (at? c) (foldl (\ i r (has? (vs r) c ? r i)) -1 ^43)   ; the row that names c
   (cols r) (net (map (b \ b & 192 != 128) (chars r)))    ; utf-8 bytes that lead a char
   _ (test (43 = #vs) !(any (r \ has? r "C1" && has? r "C7") vs) (all (r \ cols r <= 45) vs)
           (0 < at? "C7" && at? "C7" < at? "C4" && at? "C4" < at? "C1")
           (has? (vs (at? "◀")) "A3") !(has? (vs (at? "◀")) "Hz")
           (any (r \ has? r "1;38;5;148m█") vf))
   ; a bass's low E over 32768 frames stands 8 dB over the semitones either side
   e1 (pin (fresh ()) 'sp 1)
   _ (tuner-hear e1 (tuner-tone 41.2034 32768))
   _ (e1 'spec @ v (test (v 4 - v 5 > 8.0) (v 4 - v 3 > 8.0) (v 4 > -14.0)))
   _ (tuner-hear s quiet)
   _ (test (abs (s 'spec 33 - (pk - 3.0)) < 0.01))
   _ (tuner-frame s 80 20 @ r (test (20 = #r) !(has? (tuner-plain (r 17)) "C1")))
   _ (pin s 'sp 0)
   _ (test !(has? (line s 27) "C1"))
   ; a window with no screen: one turn's events, then its frame on paper
   tw (pin (fresh ()) 'sp 1)
   _ (tuner-hear tw (tuner-sine 220.0))
   twd {'w 640 'h 480 'paper (cask (640 * 480 * 4))
        'evq [['text "s"] ['press 1 600 100] ['press 1 10 100] ['press 1 10 100] ['close]]}
   _ (test (tuner-glass tw twd = 0) (tw 'sp = 0) (tw 'ref = 439.0) (tw 'over = 1))
   tpp (string (twd 'paper))
   (tpx x y) (4 * (y * 640 + x) @ i [(tpp (i + 2)) (tpp (i + 1)) (tpp i)])
   _ (test (tpx 4 4 != [0 0 0]) (24 < net (map (y \ any (x \ tpx x (16 * y + 8) != [0 0 0]) ^640) ^30)))
   ; the room: a hush sets the floor, a tone under three floors is room too, one well over is heard
   q (fresh ())
   _ (tuner-hear q (tuner-sine 440.0 * 0.008))
   fl (q 'floor)
   _ (tuner-hear q (tuner-sine 220.0 * 0.015))
   _ (test !(q 'c) (0 < fl < 80.0) (fl < q 'floor < 1.02 * fl)
           (has? (tuner-plain (tuner-frame q 60 12 @ r (r 9))) "(listening)"))
   _ (tuner-hear q (tuner-sine 220.0 * 0.5))
   (test (cents-off (q 'hz) 220.0 < 1.0)))

(test_fin (), puts "tuner: ok", putc 10, 0)
