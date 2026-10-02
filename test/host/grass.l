; test/host/grass.l -- leaves of grass, headless: the clock and sky, water given and taken by the
; weather, a blade growing, the dance, the words, the helm, the week's end, the song, the frame.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/grass.l | out/love

(borrow 'grass)   ; the artifact's module, warm from the tree
(borrow 'score)   ; the tune's reader, for the song laws
(borrow 'meadow)  ; the field's pens, for the three-dimensional laws

(: (ticks g n) (0 < n ? (grass-tick g, ticks g (n - 1)) g)
   ; a row in cells: a glyph's tail bytes ride the lead that began it
   (wide s) (:- (go 0 0) (go i n) (i >= #s ? n (go (i + 1) (n + (128 <= s i < 192 ? 0 1)))))
   (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   ; a known week: mild days and every blade equally thirsty, so the laws below do not
   ; ride the dice. the field flat, as the laws of its rows read it; (solid) stands it up
   (fresh _) (grass-new 23 80 (wheel 12) @ g
              (each (g 'bs) (b \ pins b 'wf 1.0 'hy 80.0),
               pins g 'tdays '(58.0 58.0 58.0 58.0 58.0 58.0 58.0) 'covers '(0.5 0.5 0.5 0.5 0.5 0.5 0.5) 'flat 1))
   (solid _) (fresh () @ g (pin g 'flat 0)))

; --- the clock and the sky ---
(fresh () @ g
 (test
  (0 < #(grass-hud g)) (wide (grass-hud g) = 80)   ; the hud, the screen's width
  (0 < #(g 'bs)) (g 'me 'me = 1) (0.0 < g 'me 'ht) (g 'me 'hy = 80.0)
  (daylight 12.0 = 1.0) (daylight 0.0 = 0.0) (daylight 6.0 < 0.001)
  !(sky-pen 12.5 = sky-pen 0.0)                    ; noon and midnight in different skies
  (compass 0.0 = "N") (compass 90.0 = "E") (compass 270.0 = "W") (compass 359.0 = "N")
  (fx1 3.46 = "3.5") (fx1 2.0 = "2.0")))

; --- water: a calm cold night gives, a hot windy noon takes; growth rides the water ---
(: g (fresh ()) me (g 'me)
   _ (pins g 'h 22.0 'wind 2.0 'wt 2.0, each (g 'bs) (b \ pin b 'hy 50.0))
   _ (ticks g 300)                              ; four game hours, calm
   night (me 'hy)
   ht0 (me 'ht)
   _ (pins g 'h 12.0 'wind 20.0 'wt 20.0 'tdays '(80.0 80.0 80.0 80.0 80.0 80.0 80.0))
   _ (each (g 'bs) (b \ pin b 'hy 50.0))
   _ (ticks g 300)
   day (me 'hy)
 (test (50.0 < night) (day < 50.0) (ht0 < me 'ht)))

; --- every blade waters itself: its own meter, its own thirst, the sky the only hand ---
(: g (fresh ()) me (g 'me) dry <(g 'bs) wet (g 'bs 1)
   _ (pins g 'h 12.0 'wind 10.0 'wt 10.0 'tdays '(80.0 80.0 80.0 80.0 80.0 80.0 80.0))
   _ (pins dry 'hy 14.0 'wf 1.0, pins wet 'hy 14.0 'wf 0.0)
   hy0 (me 'hy)
   (ticks g 150,                                ; two game hours of a hot noon
    test (dry 'hy < 12.0 < wet 'hy)             ; the thirsty one wilts, the other does not
         (me 'hy < hy0)))

; --- the dewfall: before dawn every blade drinks, once a day ---
(: g (fresh ())
   _ (pins g 'h 28.9 'wind 20.0 'wt 20.0, each (g 'bs) (b \ pin b 'hy 40.0))
   _ (ticks g 30) once (g 'me 'hy)
   _ (ticks g 30) twice (g 'me 'hy)
 (test (40.0 < once) (|(twice - once) < 1.0)))

; --- the dance: another key inside the gap is the combo, the same key or a slow one is not ---
(: g (fresh ())
   _ (grass-key g -1 1000) c1 (g 'combo)
   _ (grass-key g -2 1200) c2 (g 'combo)
   _ (grass-key g -8 1300) c3 (g 'combo)
   _ (grass-key g -8 1400) c4 (g 'combo)
   _ (grass-key g -1 3000) c5 (g 'combo)
   pts (g 'pts) hy (g 'me 'hy)
   (grass-key g 32 3100,                       ; not a steer: nothing
    grass-key g 113 3200,
    test (c1 = 1) (c2 = 2) (c3 = 3) (c4 = 1) (c5 = 1) (pts = 1 + 2 + 3 + 1 + 1)
         (hy = 80.0) (g 'over = 'fled)            ; the dance is free: water is the weather's
         (0 < #(grass-final g))))

; --- the end: seven days, then nothing more happens ---
(: g (fresh ())
   _ (pin g 'h (week-hours - 0.01))
   _ (ticks g 2) ht (g 'me 'ht)
   (ticks g 100,
    test (g 'over = 'done) (g 'me 'ht = ht)
         (0 < #(grass-final g))
         (grass-key g -1 0 'over = 'done)))       ; no dancing after

; --- the stretch: up lengthens you, down shortens you, both ring back to rest ---
(: g (fresh ()) me (g 'me)
   _ (grass-key g -8 1000, ticks g 3) up (me 's)
   _ (ticks g 200) back (me 's)
   _ (grass-key g -9 9000, grass-key g -9 9500, ticks g 3) down (me 's)
   _ (pins me 'th 0.5 'ht 6.0)
   f (grass-frame g)
   _ (pins me 's 0.0 'sv 0.0) f0 (grass-frame g)
   (pins me 's 0.0 'sv 0.0 'w 0.0, grass-key g 110 20000, ticks g 3,             ; n: down and to the right
    test (0.05 < up) (|back < 0.01) (down < -0.1) (f != f0)
         (me 's < -0.05) (0.0 < me 'w) (0 < #(g 'msg))))

; --- a tap: the direction from your blade to the cell, as a key ---
(: g (fresh ()) me (g 'me) x (me 'x) mid (23 - 4 - 2)   ; a 2-inch blade is 4 rows: its middle two up
   _ (pin g 'h 12.0)
   _ (grass-tap g [(x - 10) mid] 1000) left (me 'w)
   _ (grass-tap g [(x + 10) mid] 1100) right (me 'w)
   _ (grass-tap g [x (mid - 8)] 1200) up (g 'msg) sv (me 'sv)
   _ (grass-tap g [(x + 9) (mid + 4)] 1300) diag (g 'msg)
   pts (g 'pts)
   (grass-tap g [x mid] 1400,
    test (left < 0.0) (right > left) (0 < #up) (0.0 < sv) (0 < #diag) (me 'sv < sv)
         (pts = 1 + 2 + 3 + 4) (g 'pts = pts)))          ; a tap on the blade itself is nothing

; --- the words: up says what is in the sky, day or night, and down says something else ---
(: g (fresh ())
   _ (pin g 'h 12.0, grass-key g -8 1000) sun (g 'msg)
   _ (pin g 'h 23.0, grass-key g -8 2000) moon (g 'msg)
   _ (grass-key g -9 2100) bow (g 'msg)
   _ (grass-key g -1 2200) side (g 'msg)
 (test (0 < #sun) (0 < #moon) !(sun = moon) (0 < #bow) !(bow = moon) (0 < #side)))

; --- the song: chimes off the score's pitches, the daily cue, the song on cue and then chimes again ---
(: bs (score-parse score)
   j (jug 0)
   s (grass-song-new bs j (wheel 7))
   (feed n w) (0 < n ? (grass-song-feed s w, feed (n - 1) w) s)
   _ (feed 90 30.0)                            ; three seconds of a gale
   blown #(s 'vs)
   ; ..and under the page's cap the same gale rings four at most
   s4 (grass-song-new bs (jug 0) (wheel 7)) _ (pin s4 'cap 4)
   (feed4 n) (0 < n ? (grass-song-feed s4 30.0, feed4 (n - 1)) s4)
   _ (feed4 90) capped #(s4 'vs)
   _ (feed 90 0.0) calm #(s 'vs)                ; three seconds of calm: the gale's chimes ring on, few new ones
   set (s 'set)
   _ (grass-song-cue s, feed 2 0.0)
   sung (s 'mode) sv #(s 'vs)
   _ (feed (int (6 / 0.32 * 30)) 0.0)         ; the six bars through
   after (s 'mode)
   ; the cue: once a day at the day's hour, never twice
   g (fresh ()) _ (pins g 'songs '(7.0 7.0 7.0 7.0 7.0 7.0 7.0) 'h 6.9)
   _ (ticks g 30) c1 (g 'cue) _ (pin g 'cue 0, ticks g 300) c2 (g 'cue)
   _ (pin g 'h 30.9, ticks g 30) c3 (g 'cue)
 (test (3 < blown < 30) (calm <= blown + 3) (2 <= capped <= 4)
       (0 < #set)                                                               ; the melody's notes
       (sung = 'song) (0 < sv) (after = 'chimes) (0 < s 'cyc)
       (#(slurp j) = 4 * song-chunk * (182 + int (6 / 0.32 * 30)))
       (c1 = 1) (c2 = 0) (c3 = 1)))

; --- the frame on a real console: every row reaches the last column and keeps it. an
;     erase after a full row takes the glyph that raised the pending wrap, so the score
;     lost its last digit and the field its last stalk
(: (mkscr r c) (screen (cask (screen () r c)) r c)
   (chat s i) (2097151 & glass s i 0)
   g (fresh ()) _ (pin g 'h 12.0)
   s (mkscr 24 80)
   (scribe s (grass-frame g),
    test (chat s 79 != 0) (chat s 79 != 32)      ; the hud's last cell holds
         (chat s 159 != 0)))                      ; ..and the first field row's

; --- the frame: r rows and a bar, and noon is not midnight ---
(: g (fresh ())
   _ (pin g 'h 12.0) noon (grass-frame g)
   _ (pin g 'h 1.0) night (grass-frame g)
 (test (count noon "\r\n" = 23) (count night "\r\n" = 23)
       !(noon = night)))

; --- the kept rows: a frame off the kept rows and clouds is the frame a fresh painter
;     says, by day and by night, and rows were kept
(: g (fresh ()) _ (pin g 'h 12.0)
   _ (grass-frame g, ticks g 30) a (grass-frame g)
   _ (pins g 'kept {} 'cm ()) b (grass-frame g)
   _ (pin g 'h 1.0, grass-frame g, ticks g 5) n1 (grass-frame g)
   _ (pins g 'kept {} 'cm ()) n2 (grass-frame g)
 (test (a = b) (n1 = n2) (0 < #(keys (g 'kept)))))

; --- a paint: the first is the whole frame; after ticks it is the rows that changed,
;     under their cursor moves, and a screen taking the paints shows the frame
(: (mkscr r c) (screen (cask (screen () r c)) r c)
   (cells s n) (map (i \ [(glass s i 0) (glass s i 1) (glass s i 2)]) (jot n))
   g (fresh ()) _ (pin g 'h 12.0)
   a (mkscr 24 80) b (mkscr 24 80)
   p0 (grass-paint g) _ (scribe a p0)
   _ (ticks g 10) p1 (grass-paint g) _ (scribe a p1)
   _ (ticks g 10) p2 (grass-paint g) _ (scribe a p2)
   _ (scribe b (grass-frame g))
   n (24 * 80)
 (test (p0 = grass-frame g || 1)                   ; (the first paint says every row)
       (count p0 "\r\n" = 23) (count p1 "\r\n" < 16) (count p2 "\r\n" < 16)
       (cells a n = cells b n)))

; --- the field in three dimensions: the same rows, the hud and the bar either side of the
;     meadow; noon is not midnight; your lean moves the picture; v lays it flat and back;
;     every pen a number in the eye's range, at noon and at night, with the field wilting
(: (mkscr r c) (screen (cask (screen () r c)) r c)
   (chat s i) (2097151 & glass s i 0)
   (sane c) (all (k \ aall (0.0 <= c k) && aall (c k <= 1.0)) ^3)
   g (solid ()) me (g 'me)
   _ (pin g 'h 12.0) noon (grass-frame g)
   _ (pins me 'th 0.8 'ht 4.0) leant (grass-frame g)
   _ (pin g 'h 1.0) night (grass-frame g)
   _ (each (g 'bs) (b \ pin b 'hy 15.0))
   dry (sane (meadow-pens (g 'mv) g (meadow-sky g)))
   _ (pin g 'h 12.0) dryday (sane (meadow-pens (g 'mv) g (meadow-sky g)))
   _ (grass-key g 118 0) flat (g 'flat) fl (grass-frame g)
   _ (grass-key g 118 0) back (g 'flat)
   s (mkscr 24 80)
   (scribe s night,
    test (count noon "\r\n" = 23) (count night "\r\n" = 23) !(noon = night) !(noon = leant)
         dry dryday (flat = 1) (back = 0) !(fl = night) (count fl "\r\n" = 23)
         (chat s 79 != 0) (chat s (22 * 80 + 79) != 0)))     ; the hud's last cell, the meadow's last row

(test_fin (),
 puts "grass: ok -- the tune reads, the week waters, the frame paints day and night, the kept rows say the same, a paint is the rows that moved, and the field stands up in three dimensions\n")
