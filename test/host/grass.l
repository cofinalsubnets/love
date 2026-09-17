; --- test/host/grass.l: leaves of grass, headless ---
; not in the test/*.l corpus (it loads a crew module). the game is pure love, so
; everything but the tty runner gates here: the clock and the sky, a calm cold night
; giving water back and a hot windy noon taking it, a blade growing on it, the dance
; combo and what it costs, the words a reach and a bow say, the helm leaving, the
; week's end, the song and its chimes, and the frame's pens by hour.
;   cat test/00-init.l test/host/grass.l | out/love

(borrow 'grass)   ; the artifact's module, warm from the tree
(borrow 'score)   ; the tune's reader, for the song laws

(: (find h n i) (? (i + tally n < 1 + tally h)
                  (? (n = snip h i (i + tally n)) 1 (find h n (i + 1)))
                  0)
   (has? h n) (find h n 0)
   (ticks g n) (? (0 < n) (grass-tick g, ticks g (n - 1)) g)
   ; a row in cells: a glyph's tail bytes ride the lead that began it
   (wide s) (:- (go 0 0) (go i n) (i >= #s ? n (go (i + 1) (n + (128 <= s i < 192 ? 0 1)))))
   (count s n) (:- (go 0 0) (go i k) (? (i + tally n <= tally s)
                                       (go (i + 1) (k + (n = snip s i (i + tally n)))) k))
   ; a known week: mild days and every blade equally thirsty, so the laws below do not
   ; ride the dice
   (fresh _) (: g (grass-new 23 80 (wheel 12))
                _ (each (g 'bs) (b \ pins b 'wf 1.0 'hy 80.0))
                (pins g 'tdays '(58.0 58.0 58.0 58.0 58.0 58.0 58.0) 'covers '(0.5 0.5 0.5 0.5 0.5 0.5 0.5))))

; --- the clock and the sky ---
(: g (fresh ())
 (test
  (has? (grass-hud g) "mon 06:00") (has? (grass-hud g) "H2O 80%")
  (wide (grass-hud g) = 80)                     ; the day left, you right, the screen's width
  ("score 0" = snip (grass-hud g) (#(grass-hud g) - 7) #(grass-hud g))
  (0 < #(g 'bs)) (g 'me 'me = 1) (g 'me 'ht = 2.0) (g 'me 'hy = 80.0)
  (daylight 12.0 = 1.0) (daylight 0.0 = 0.0) (daylight 6.0 < 0.001)
  (sky-pen 12.5 = 39) (sky-pen 0.0 = 17)
  (compass 0.0 = "N") (compass 90.0 = "E") (compass 270.0 = "W") (compass 359.0 = "N")
  (fx1 3.46 = "3.5") (fx1 2.0 = "2.0")))

; --- water: a calm cold night gives, a hot windy noon takes; growth rides the water ---
(: g (fresh ()) me (g 'me)
   _ (pins g 'h 22.0 'wind 2.0 'wt 2.0) _ (each (g 'bs) (b \ pin b 'hy 50.0))
   _ (ticks g 300)                              ; four game hours, calm
   night (me 'hy)
   ht0 (me 'ht)
   _ (pins g 'h 12.0 'wind 20.0 'wt 20.0 'tdays '(80.0 80.0 80.0 80.0 80.0 80.0 80.0))
   _ (each (g 'bs) (b \ pin b 'hy 50.0))
   _ (ticks g 300)
   day (me 'hy)
 (test (50.0 < night) (day < 50.0) (ht0 < me 'ht) (has? (grass-hud g) "H2O")))

; --- every blade waters itself: its own meter, its own thirst, the sky the only hand ---
(: g (fresh ()) me (g 'me) dry (<(g 'bs)) wet ((g 'bs) 1)
   _ (pins g 'h 12.0 'wind 10.0 'wt 10.0 'tdays '(80.0 80.0 80.0 80.0 80.0 80.0 80.0))
   _ (pins dry 'hy 14.0 'wf 1.0) _ (pins wet 'hy 14.0 'wf 0.0)
   hy0 (me 'hy)
   _ (ticks g 150)                              ; two game hours of a hot noon
 (test (dry 'hy < 12.0 < wet 'hy)             ; the thirsty one wilts, the other does not
       (me 'hy < hy0)
       (has? (grass-frame g) "38;5;142;")))     ; ..and a wilted blade is painted for it

; --- the dewfall: before dawn every blade drinks, once a day ---
(: g (fresh ())
   _ (pins g 'h 28.9 'wind 20.0 'wt 20.0) _ (each (g 'bs) (b \ pin b 'hy 40.0))
   _ (ticks g 30) once (g 'me 'hy)
   _ (ticks g 30) twice (g 'me 'hy)
 (test (58.0 < once < 62.0) (|(twice - once) < 1.0) (has? (grass-bar g) "dew")))

; --- the dance: another key inside the gap is the combo, the same key or a slow one is not ---
(: g (fresh ())
   _ (grass-key g -1 1000) c1 (g 'combo)
   _ (grass-key g -2 1200) c2 (g 'combo)
   _ (grass-key g -8 1300) c3 (g 'combo)
   _ (grass-key g -8 1400) c4 (g 'combo)
   _ (grass-key g -1 3000) c5 (g 'combo)
   pts (g 'pts) hy (g 'me 'hy)
   _ (grass-key g 32 3100)                     ; not a steer: nothing
   _ (grass-key g 113 3200)
 (test (c1 = 1) (c2 = 2) (c3 = 3) (c4 = 1) (c5 = 1) (pts = 8)
       (hy = 80.0) (g 'over = 'fled)            ; the dance is free: water is the weather's

       (has? (grass-final g) "left the field")))

; --- the end: seven days, then nothing more happens ---
(: g (fresh ())
   _ (pin g 'h (week-hours - 0.01))
   _ (ticks g 2) ht (g 'me 'ht)
   _ (ticks g 100)
 (test (g 'over = 'done) (g 'me 'ht = ht)
       (has? (grass-hud g) "mon 06:00")
       (has? (grass-final g) "seven days")
       (grass-key g -1 0 'over = 'done)))       ; no dancing after

; --- the stretch: up lengthens you, down shortens you, both ring back to rest ---
(: g (fresh ()) me (g 'me)
   _ (grass-key g -8 1000) _ (ticks g 3) up (me 's)
   _ (ticks g 200) back (me 's)
   _ (grass-key g -9 9000) _ (grass-key g -9 9500) _ (ticks g 3) down (me 's)
   _ (pins me 'th 0.5 'ht 6.0)
   f (grass-frame g)
   _ (pins me 's 0.0 'sv 0.0) f0 (grass-frame g)
   _ (pins me 's 0.0 'sv 0.0 'w 0.0) _ (grass-key g 110 20000) _ (ticks g 3)     ; n: down and to the right
 (test (0.05 < up) (|back < 0.01) (down < -0.1) (f != f0)
       (me 's < -0.05) (0.0 < me 'w) (has? (g 'msg) "bow")))

; --- a tap: the direction from your blade to the cell, as a key ---
(: g (fresh ()) me (g 'me) x (me 'x) mid (23 - 4 - 2)   ; a 2-inch blade is 4 rows: its middle two up
   _ (pin g 'h 12.0)
   _ (grass-tap g [(x - 10) mid] 1000) left (me 'w)
   _ (grass-tap g [(x + 10) mid] 1100) right (me 'w)
   _ (grass-tap g [x (mid - 8)] 1200) up (g 'msg) sv (me 'sv)
   _ (grass-tap g [(x + 9) (mid + 4)] 1300) diag (g 'msg)
   pts (g 'pts)
   _ (grass-tap g [x mid] 1400)
 (test (left < 0.0) (right > left) (has? up "reach for the sun") (0.0 < sv) (has? diag "bow") (me 'sv < sv)
       (pts = 1 + 2 + 3 + 4) (g 'pts = pts)))          ; a tap on the blade itself is nothing

; --- the words: up reaches for what is in the sky, down bows ---
(: g (fresh ())
   _ (pin g 'h 12.0) _ (grass-key g -8 1000) sun (g 'msg)
   _ (pin g 'h 23.0) _ (grass-key g -8 2000) moon (g 'msg)
   _ (grass-key g -9 2100) bow (g 'msg)
   _ (grass-key g -1 2200) side (g 'msg)
 (test (sun = "you reach for the sun") (moon = "you reach for the moon")
       (has? bow "you bow to the") (has? bow "combo x2") (side = "combo x3")))

; --- the song: chimes off the score's pitches, the daily cue, the song on cue and then chimes again ---
(: bs (score-parse score)
   j (jug 0)
   s (grass-song-new bs j (wheel 7))
   (feed n w) (? (0 < n) (grass-song-feed s w, feed (n - 1) w) s)
   _ (feed 90 30.0)                            ; three seconds of a gale
   blown #(s 'vs)
   _ (feed 90 0.0) calm #(s 'vs)                ; three seconds of calm: the gale's chimes ring on, few new ones
   set (s 'set)
   _ (grass-song-cue s) _ (feed 2 0.0)
   sung (s 'mode) sv #(s 'vs)
   _ (feed (int (6 / 0.32 * 30)) 0.0)         ; the six bars through
   after (s 'mode)
   ; the cue: once a day at the day's hour, never twice
   g (fresh ()) _ (pins g 'songs '(7.0 7.0 7.0 7.0 7.0 7.0 7.0) 'h 6.9)
   _ (ticks g 30) c1 (g 'cue) _ (pin g 'cue 0) _ (ticks g 300) c2 (g 'cue)
   _ (pin g 'h 30.9) _ (ticks g 30) c3 (g 'cue)
 (test (3 < blown < 30) (calm <= blown + 3)
       (#set = 6) (elem 11 set) (elem 13 set) (elem 1 set) !(elem 0 set) !(elem 7 set)   ; the melody's notes, sharped by the key
       (sung = 'song) (0 < sv) (after = 'chimes) (s 'cyc = 6)
       (#(slurp j) = 4 * song-chunk * (182 + int (6 / 0.32 * 30)))
       (c1 = 1) (c2 = 0) (c3 = 1)))

; --- the frame on a real console: every row reaches the last column and keeps it. an
;     erase after a full row takes the glyph that raised the pending wrap, so the score
;     lost its last digit and the field its last stalk
(: (mkscr r c) (screen (cask (screen () r c)) r c)
   (chat s i) (& 255 (glass s i))
   g (fresh ()) _ (pin g 'h 12.0)
   s (mkscr 24 80)
   _ (scribe s (grass-frame g))
 (test (chat s 79 = 48)                         ; the hud's last cell: score 0
       (chat s 159 != 0)))                      ; ..and the first field row's

; --- the frame: r rows and a bar, the sky's pen by hour, shadows by day, stars by night ---
(: g (fresh ())
   _ (pin g 'h 12.0) noon (grass-frame g)
   _ (pin g 'h 1.0) night (grass-frame g)
 (test (count noon "\r\n" = 23) (count night "\r\n" = 23)
       (has? noon "48;5;39m") !(has? noon "48;5;17m")
       (has? night "48;5;17m") !(has? night "48;5;39m")
       (has? noon "48;5;58m")                   ; a shadow on the dirt
       (has? noon "48;5;220m")                  ; the sun
       (has? noon "48;5;255m") (has? noon "▓") (has? noon "░")   ; clouds, shaded
       (has? night "48;5;252m")                 ; the moon
       (has? night "38;5;230;")                 ; stars
       (has? noon "38;5;118;")))                ; you, in the bright green
