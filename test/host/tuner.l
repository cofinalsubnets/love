; test/host/tuner.l -- the tuner (src/apps/tuner.l): the ear on known tones, the scale's
; eighth tones and their octaves, the reading's smoothing and the room's floor, a frame
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
   t (tuner-new 440.0 "law")
   _ (tuner-hear t (tuner-sine 445.0))
   fr (tuner-frame t 80 30)
   rs (map tuner-plain fr)
   (has? s n) (0 <= fsub s n 0)
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
   ; the room: a hush reads no pitch and sets the floor, a tone under three floors is the
   ; room too (the floor creeping up a percent), and one well over it is heard
   q (tuner-new 440.0 "law")
   _ (tuner-hear q (tuner-sine 440.0 * 0.008))
   fl (q 'floor)
   _ (tuner-hear q (tuner-sine 220.0 * 0.015))
   _ (test !(q 'hz) (0 < fl < 80.0) (fl < q 'floor < 1.02 * fl)
           (has? (tuner-plain (tuner-frame q 60 12 @ r (r 9))) "(listening)"))
   _ (tuner-hear q (tuner-sine 220.0 * 0.5))
   (test (cents-off (q 'hz) 220.0 < 1.0)))

(test_fin (), puts "tuner: ok", putc 10, 0)
