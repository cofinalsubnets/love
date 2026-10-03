; grass99 -- grass simulator 1999: the sequel. the same week as a blade of
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
 ; the tune as a score, read as grass reads its own: gwen's bar, picked out on synth's row
 ; as 3 6 0 8 6, on the music box alone -- spread over two bars, so at grass's tempo it
 ; goes half as fast, and an octave under, the box's own low end and the chimes' with it
 score99 '("D3 1.5 F3 1.5 A3 1"
           "G3 1.5 F3 2.5")
 ttl99 "grass simulator 1999"
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
 ; ..painted whole every tick: no row of it stands still for long
 grass99-look {'ttl ttl99 'rows rows99 'frame grass99-frame 'paint grass99-frame}
 grass99-usage "usage: love lore grass99   (dance: arrows, hjkl, or tap about your blade; q or esc leaves)"
 (grass99-main as) (as @ () (grass-run grass99-look score99)
                         (say err ("grass99: " + grass99-usage + "\n"), flush err, 2))
 _ ((cite 'lore 'lore-enlist) 'grass99 (udoor 'grass99 grass99-main grass99-usage 1 1)))
) ; module grass99
