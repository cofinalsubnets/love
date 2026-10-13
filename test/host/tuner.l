; test/host/tuner.l -- the tuner (src/apps/tuner.l): the ear on known tones, the scale's
; eighth tones and their octaves, a frame, the reading's smoothing, range and hold, and
; the room's floor. the clock is the law's own, so the hold needs no waiting
;   cat test/00-init.l test/host/tuner.l | out/love
(borrow 'tuner)
(: (cents-off f g) (abs (1200.0 * log (f / g) / log 2.0))
   (heard f) (tuner-yin (tuner-sine f))
   quiet (tuner-sine 440.0 * 0.0)
   ; the ear: within a cent from a bass's low B to two octaves over A4, nothing in silence
   _ (test (cents-off (heard 440.0) 440.0 < 1.0) (cents-off (heard 82.41) 82.41 < 1.0)
           (cents-off (heard 61.74) 61.74 < 1.0) (cents-off (heard 261.63) 261.63 < 1.0)
           (cents-off (heard 1760.0) 1760.0 < 1.0) !(tuner-yin quiet))
   ; a row is an eighth tone, cents over midi 0 by 25: A4 is 276, C4 240, and the rows
   ; between semitones are their eighths
   _ (test (["A" 4 0] = tuner-note 276) (["C" 4 0] = tuner-note 240) (["C" 4 1] = tuner-note 241)
           (["B" 3 3] = tuner-note 239) (["C" 0 0] = tuner-note 48) (["A♯" 4 2] = tuner-note 282)
           (6900.0 = tuner-cents 440.0 440.0) (abs (tuner-cents 442.0 440.0 - 6892.15) < 0.01))
   ; a frame at 445: thirty rows, the marker on the eighth over A4 and A4's semitone under it,
   ; the semitones four rows apart, A4 in octave 4's hue and C5 in 5's, the needle right of centre
   clk {'now 0}
   (fresh _) (pins (tuner-new 440.0 "law") 'clock (_ \ clk 'now) 'sp 0)     ; the scale alone
   t (fresh ())
   _ (tuner-hear t (tuner-sine 445.0))
   fr (tuner-frame t 80 30)
   rs (map tuner-plain fr)
   (has? s n) (0 <= fsub s n 0)
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
   ; the range: 440 then 452, under a quarter tone apart, is one note whose raw cents span
   ; +0..+47 off A4 -- in the marker, solid along the axis over its three eighths, and drawn
   ; on the needle
   g (fresh ())
   _ (tuner-hear g (tuner-sine 440.0))
   _ (tuner-hear g (tuner-sine 452.0))
   gs (map tuner-plain (tuner-frame g 80 30))
   _ (test (has? (gs 14) "+0…+47¢") (has? (gs 13) "█") (has? (gs 14) "█") (has? (gs 15) "█")
           !(has? (gs 12) "█") !(has? (gs 16) "█") (has? (gs 27) "━"))
   ; the hold: a silence keeps the reading, faint, for 2.5 s, then the scale listens;
   ; a pitch after that is a new note, its range begun again
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
   ; the needle: a pitch wobbling 440/446 Hz (0 and +23 cents) holds it still between them,
   ; where the reading swings eighteen cells; a change that stays still arrives
   j (fresh ())
   (cell x) (: _ (tuner-frame x 80 30) <>(x 'ncell))
   (feed f k acc) (k = 0 ? (rev acc) (: _ (tuner-hear j (tuner-sine (f k))) (feed f (k - 1) (cell j . acc))))
   wob (drop 8 (feed (k \ k % 2 = 0 ? 440.0 446.0) 16 ()))
   held (feed (_ \ 452.0) 16 ())
   _ (test (last (sort wob) - <(sort wob) <= 1) (abs (<wob - 47) <= 1) (abs (last held - 73) <= 1))
   ; the spectrum: A3 with a third of its twelfth over it peaks at A3's bin, E5's stands
   ; clear, and the floor far from both is under -60 dBFS; the strip takes six rows of a
   ; tall frame, its labels each octave's C, A3's column bold. a silence lets it fall 3 dB a
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
   _ (tuner-hear s quiet)
   _ (test (abs (s 'spec 33 - (pk - 3.0)) < 0.01))
   _ (tuner-frame s 80 20 @ r (test (20 = #r) !(has? (tuner-plain (r 17)) "C1")))
   _ (pin s 'sp 0)
   _ (test !(has? (line s 27) "C1"))
   ; the room: a hush reads no pitch and sets the floor, a tone under three floors is the
   ; room too (the floor creeping up a percent), and one well over it is heard
   q (fresh ())
   _ (tuner-hear q (tuner-sine 440.0 * 0.008))
   fl (q 'floor)
   _ (tuner-hear q (tuner-sine 220.0 * 0.015))
   _ (test !(q 'c) (0 < fl < 80.0) (fl < q 'floor < 1.02 * fl)
           (has? (tuner-plain (tuner-frame q 60 12 @ r (r 9))) "(listening)"))
   _ (tuner-hear q (tuner-sine 220.0 * 0.5))
   (test (cents-off (q 'hz) 220.0 < 1.0)))

(test_fin (), puts "tuner: ok", putc 10, 0)
