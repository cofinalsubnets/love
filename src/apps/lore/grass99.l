; grass99 -- leaves of grass simulator 1999: the sequel. the same week as a blade of
; grass, the same field, the same weather and the same dance -- grass's own state and
; rules, ticked by grass's own loop -- stood up in three dimensions by meadow, with a
; tune of its own.
;
; run: love lore grass99
(module (grass99 grass99-main grass99-look grass99-frame score99)
(borrow 'rove)
(borrow 'grass)                         ; the week: its state, its rules, its loop
(borrow 'meadow)                        ; the field in three dimensions
(:
 esc (string 27)
 ; the tune as a score, read as grass reads its own: a bar to the line, in B flat. gwen's
 ; melody, picked out on synth's row as 6 8 - 4 3 / 3 6 0 8 6, is the first four bars;
 ; the last four answer it, the climb going on to d, the sigh an octave up, the walk home
 score99 '("key Bb Eb"
           "[Bb] F4 .5 G4 .5 Bb4 3"
           "[Gm] Eb4 1.5 D4 2.5"
           "[Dm] D4 .5 F4 .5 A4 3"
           "[F] G4 1.5 F4 2.5"
           "[Bb] F4 .5 G4 .5 Bb4 1 C5 .5 D5 1.5"
           "[Gm] Eb5 1.5 D5 2.5"
           "[F] D5 .5 C5 .5 Bb4 1 A4 2"
           "[Bb] G4 1 A4 1 Bb4 2")
 ttl99 "leaves of grass simulator 1999"
 rows99 '(""
          "hjkl or arrows keys to dance"
          "q or esc to quit"
          ""
          "-- any key --")
 ; the frame: the hud, the meadow under the rows between, and the bar. the meadow's
 ; screen is laid at the first frame, its own blades thrown from the week's first day,
 ; its colours 24-bit where the seat says so
 (lay g) (: m (meadow-new (int (g 'tdays 0 * 977.0)) (g 'c) (2 * (g 'r - 1)))
             (pin m 'deep (elem (getenv "COLORTERM") ["truecolor" "24bit"]),
              pin g 'mv m,
              m))
 (grass99-frame g) (: r (g 'r) c (g 'c)
   mv (g 'mv @ m (tablet? m ? m (lay g)))
   (esc + "[H" + esc + "[0m" + fit (grass-hud g) c + "\r\n" + meadow-frame mv g (meadow-sky g) (mv 'deep)
    + "\r\n" + esc + "[0m" + fit (grass-bar g) (c - 1) + esc + "[K"))
 ; ..painted whole every tick: no row of it stands still for long; the song sung through the
 ; tuner
 grass99-look {'ttl ttl99 'rows rows99 'frame grass99-frame 'paint grass99-frame 'voice "cher"}
 grass99-usage "usage: love lore grass99   (dance: arrows, hjkl, or tap about your blade; q or esc leaves)"
 (grass99-main as) (as @ () (grass-run grass99-look score99)
                         (say err ("grass99: " + grass99-usage + "\n"), flush err, 2))
 _ ((cite 'lore 'lore-enlist) 'grass99 (udoor 'grass99 grass99-main grass99-usage 1 1)))
) ; module grass99
