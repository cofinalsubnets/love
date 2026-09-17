; --- test/host/grass.l: leaves of grass, headless ---
; not in the test/*.l corpus (it loads a crew module). the game is pure love, so
; everything but the tty runner gates here: the clock and the sky, a calm cold night
; giving water back and a hot windy noon taking it, a blade growing on it, the dance
; combo and what it costs, the words a reach and a bow say, the helm leaving, the
; week's end, and the frame's pens by hour.
;   cat test/00-init.l test/host/grass.l | out/love

(borrow 'grass)   ; the artifact's module, warm from the tree

(: (find h n i) (? (i + tally n < 1 + tally h)
                  (? (n = snip h i (i + tally n)) 1 (find h n (i + 1)))
                  0)
   (has? h n) (find h n 0)
   (ticks g n) (? (0 < n) (grass-tick g, ticks g (n - 1)) g)
   (count s n) (:- (go 0 0) (go i k) (? (i + tally n <= tally s)
                                       (go (i + 1) (k + (n = snip s i (i + tally n)))) k))
   ; a known week: mild days, so the laws below do not ride the dice
   (fresh _) (: g (grass-new 23 80 (wheel 11))
                (pins g 'tdays '(58.0 58.0 58.0 58.0 58.0 58.0 58.0) 'covers '(0.5 0.5 0.5 0.5 0.5 0.5 0.5))))

; --- the clock and the sky ---
(: g (fresh ())
 (test
  (has? (grass-hud g) "day 1 mon 06:00")
  (0 < #(g 'bs)) (g 'me 'me = 1) (g 'me 'ht = 2.0) (g 'hy = 80.0)
  (daylight 12.0 = 1.0) (daylight 0.0 = 0.0) (daylight 6.0 < 0.001)
  (sky-pen 12.5 = 39) (sky-pen 0.0 = 17)
  (compass 0.0 = "N") (compass 90.0 = "E") (compass 270.0 = "W") (compass 359.0 = "N")
  (fx1 3.46 = "3.5") (fx1 2.0 = "2.0")))

; --- water: a calm cold night gives, a hot windy noon takes; growth rides the water ---
(: g (fresh ())
   _ (pins g 'h 22.0 'wind 2.0 'wt 2.0 'hy 50.0 'fh 50.0)
   _ (ticks g 300)                              ; four game hours, calm
   night (g 'hy)
   ht0 (g 'me 'ht)
   _ (pins g 'h 12.0 'wind 20.0 'wt 20.0 'hy 50.0 'fh 50.0 'tdays '(80.0 80.0 80.0 80.0 80.0 80.0 80.0))
   _ (ticks g 300)
   day (g 'hy)
 (test (50.0 < night) (day < 50.0) (ht0 < g 'me 'ht) (has? (grass-hud g) "water")))

; --- the dewfall: before dawn every blade drinks, once a day ---
(: g (fresh ())
   _ (pins g 'h 28.9 'wind 20.0 'wt 20.0 'hy 40.0 'fh 40.0)
   _ (ticks g 30) once (g 'hy)
   _ (ticks g 30) twice (g 'hy)
 (test (58.0 < once < 62.0) (|(twice - once) < 1.0) (has? (grass-bar g) "dew")))

; --- the dance: another key inside the gap is the combo, the same key or a slow one is not ---
(: g (fresh ())
   _ (grass-key g -1 1000) c1 (g 'combo)
   _ (grass-key g -2 1200) c2 (g 'combo)
   _ (grass-key g -8 1300) c3 (g 'combo)
   _ (grass-key g -8 1400) c4 (g 'combo)
   _ (grass-key g -1 3000) c5 (g 'combo)
   pts (g 'pts)
   _ (grass-key g 32 3100)                     ; not a steer: nothing
   _ (grass-key g 113 3200)
 (test (c1 = 1) (c2 = 2) (c3 = 3) (c4 = 1) (c5 = 1) (pts = 8)
       (|(g 'hy - 78.5) < 0.001) (g 'over = 'fled)
       (has? (grass-final g) "left the field")))

; --- the end: seven days, then nothing more happens ---
(: g (fresh ())
   _ (pin g 'h (week-hours - 0.01))
   _ (ticks g 2) ht (g 'me 'ht)
   _ (ticks g 100)
 (test (g 'over = 'done) (g 'me 'ht = ht)
       (has? (grass-hud g) "day 8 mon 06:00")
       (has? (grass-final g) "seven days")
       (grass-key g -1 0 'over = 'done)))       ; no dancing after

; --- the words: up reaches for what is in the sky, down bows ---
(: g (fresh ())
   _ (pin g 'h 12.0) _ (grass-key g -8 1000) sun (g 'msg)
   _ (pin g 'h 23.0) _ (grass-key g -8 2000) moon (g 'msg)
   _ (grass-key g -9 2100) bow (g 'msg)
   _ (grass-key g -1 2200) side (g 'msg)
 (test (sun = "you reach for the sun") (moon = "you reach for the moon")
       (has? bow "you bow to the sky") (has? bow "combo x2") (side = "combo x3")))

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
