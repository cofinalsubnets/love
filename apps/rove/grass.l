; grass -- leaves of grass simulator 1989: you are a blade of grass, for one week.
;
; the field is a row of blades on a strip of dirt under a sky, drawn in coarse colour
; cells: the sky's ground turns with the hour, clouds ride the wind, stars come out
; at night, the sun and the moon cross, and every blade throws a shadow the sun's
; length. a blade is a spring: the wind bends it and it swings back, and the one you
; are is the one the arrow keys push. that is the whole of the controls -- dancing. a
; press within a beat of the last, on another key, grows the combo, and the combo is
; the points. dancing costs water; water comes back as dew on calm cool nights and
; goes in the sun and the wind by day, and a blade with water and warmth grows. after
; seven days the week is over, and what you grew and what you scored is the end.
;
; the game is pure love -- grass-new, grass-key, grass-tick and grass-frame are state
; in and state out, gated headless by test/host/grass.l; only grass-run ties the tty.
; the song is harp's, a music box, out the horn when the seat has one.
;
; run: love grass
(module (grass grass-run grass-main grass-new grass-key grass-tick grass-frame grass-hud
         grass-bar grass-hour grass-day grass-temp grass-wind-x grass-lay grass-clouds
         grass-tune grass-song-new grass-song-feed grass-song-cue grass-final grass-tap score song-chunk
         daylight sky-pen compass fx1 week-hours dh fps dance-cost)
(borrow 'rove)
(borrow 'harp)                          ; the cycle algebra the song is scheduled by
(borrow 'score)                         ; the tune as text
(borrow 'play)                          ; the voices, the mix
(? (cite 'posix) (borrow 'posix) ())    ; close, for the horn
(:
 esc (string 27)
 fps 30
 week-secs 420.0                        ; a minute a day
 week-start 6.0                         ; monday, dawn
 week-hours 174.0                       ; ..to the next monday's dawn: seven days
 dt (1.0 / fps)                         ; a frame, in seconds
 dh (((week-hours - week-start) / week-secs) / fps)   ; ..and in game hours
 rpi 2                                  ; rows an inch of blade takes
 dance-gap 400                          ; ms within which the next press is still the dance
 dry-rate 4.0                           ; the sky's thirst: the drops an hour it takes at noon
 dry-drop 1.0                           ; ..and what one drop is worth, in points of a hundred
 dew-rate 2.3                           ; what a calm cool night gives back, an hour
 dew-hour 5.0                           ; the dewfall: just before dawn, every blade drinks
 dew-drop 20.0

 ; the tune as a score (apps/harp/score.l): a bar to the line, NAME BEATS pairs, `-` a
 ; rest, [CHORD] the bar's bass, a key line the key signature. six bars in E
 score '("key F# C# G# D#"
         "B4 .75 - .25 B4 1 G4 2"
         "B4 .75 - .25 B4 .5 F4 2 - .5"
         "B4 .75 - .25 B4 1 G4 1.5 E4 .5"
         "C5 1.75 - .25 B4 2"
         "E4 3.5 - .5"
         "C4 1 G4 1.25 - .25 F4 .25 E4 .25 C4 1")
 song-rate (love-arch @ 'wasm 16000 48000)
 song-cps 0.32                          ; bars a second: a music box wound down
 song-chunk (song-rate // 30)           ; a frame's worth, thirty a second
 song-gain 11000.0

 sky-pens '(17 17 17 17 17 18 60 174 74 39 39 39 39 39 39 39 74 111 173 96 54 18 17 17)
 day-names '("mon" "tue" "wed" "thu" "fri" "sat" "sun")
 points '("N" "NNE" "NE" "ENE" "E" "ESE" "SE" "SSE" "S" "SSW" "SW" "WSW" "W" "WNW" "NW" "NNW")
 greens '(34 40 46 82 118 154)
 dirt-dots '("." "," ":" "'")
 ; the dirt in patches of brown by light: the grounds, and the dots on them
 dirt-day '(94 130 94 137 130)  dot-day '(137 180 173)
 dirt-dusk '(94 94 95 130)      dot-dusk '(130 137)
 dirt-night '(94 94 58 95)      dot-night '(95 130)
 twinkles '("." "+" "*")

 open-ttl "leaves of grass simulator 1989"
 open-rows '(""
             "hjkl or arrows keys to dance"
             "q or esc to quit"
             ""
             "-- any key --")
 end-ttl "seven days"

 (clamp x lo hi) (x < lo ? lo (hi < x ? hi x))
 (round x) (int (x + (x < 0.0 ? -0.5 0.5)))
 (fx1 x) (: n (int (x * 10.0 + 0.5)) (show (n // 10) + "." + show (n % 10)))
 (two-dig n) (n < 10 ? ("0" + show n) (show n))
 ; what a row is worth in cells: a glyph's tail bytes belong to the lead that began it
 (wide s) (:- (go 0 0) (go i n) (i >= #s ? n (go (i + 1) (n + lead (s i)))))
 sgrs {}
 (sgr f b) (: k [f b] s (sgrs k)
              (string? s ? s
               (: s2 (esc + "[38;5;" + show f + ";48;5;" + show b + "m") (pin sgrs k s2, s2))))

 ; --- the clock and the weather --------------------------------------------------
 (grass-hour g) (g 'h % 24.0)
 (grass-day g) (: d (int (g 'h / 24.0)) (6 < d ? 6 d))
 (daylight hr) (: v (sin (pi * (hr - 6.0) / 12.0)) (v < 0.0 ? 0.0 v))
 (sky-pen hr) (sky-pens (int hr))
 ; the day's own mean, warmest mid-afternoon and coldest at three
 (grass-temp g) (: t0 ((g 'tdays) (grass-day g))
                   (t0 + 12.0 * sin (pi * (grass-hour g - 9.0) / 12.0)))
 (compass deg) (points ((int ((deg + 11.25) / 22.5)) % 16))
 ; the wind's push along the screen: it blows FROM its heading, and east is right
 (grass-wind-x g) (0.0 - (sin (g 'head * pi / 180.0)) * (g 'wind))

 ; --- a fresh field on an r by c screen ------------------------------------------
 ; a blade every other column, you in the middle; the week's temperatures and cloud
 ; covers are thrown now, so a day is what it is before it comes
 (grass-new r c st) (:
   sb {st}
   n (c // 2)
   (blade i) {'x (2 * i + 1) 'ht (1.5 + roll sb 10 / 10.0) 'th 0.0 'w 0.0
              'ph (roll sb 628 / 100.0) 'gf (0.6 + roll sb 50 / 100.0) 's 0.0 'sv 0.0
              'hy (70.0 + roll sb 25) 'wf (0.8 + roll sb 55 / 100.0)
              'dr (roll sb 2 ? 0.8 -0.8) 'me 0}
   bs (map blade ^n)
   me (bs (n // 2))
   _ (pins me 'me 1 'ht 2.0 'gf 1.0)
   tdays (map (\ _ (52.0 + roll sb 26)) ^7)
   songs (map (\ _ (roll sb 240 / 10.0)) ^7)       ; the hour each day's song comes
   covers (map (\ _ (roll sb 10 / 10.0)) ^7)
   clouds (map (\ _ {'x0 (roll sb c * 1.0) 'y (1 + roll sb (r // 2))
                     'w (6.0 + roll sb 13) 'h (1.2 + roll sb 19 / 10.0)}) ^14)
   {'r r 'c c 'h week-start 'fr 0 'sb sb 'bs bs 'me me 'tdays tdays 'covers covers 'clouds clouds
    'wind (3.0 + roll sb 10) 'wt 8.0 'head (roll sb 360 * 1.0) 'gust 1.0 'drift 0.0
    'songs songs 'sang -1 'cue 0
    'dewday 0 'pts 0 'combo 0 'dk 0 'dms 0 'lk 0 'lt 0 'over 0 'msg ""})

 ; --- the helm: an arrow or hjkl pushes your blade, q or esc leaves ---------------
 ; a press within the gap of the last, on another key, grows the combo; the combo
 ; is the points. sideways is a shove on the lean; up is a reach that stretches the
 ; blade, down a bow that shortens it -- and a blade shortened hard enough buckles. a
 ; diagonal (yubn) is both at once
 (grass-key g k now) (: mv (steer k) me (g 'me)
   (? (g 'over) g
      (k @ (113 || 27) 1 0) (pins g 'over 'fled 'msg "")
      (one? mv) g
      (: dx <mv dy <>mv
         combo (? (k != g 'dk && (now - g 'dms) < dance-gap) (1 + g 'combo) 1)
         ; a diagonal does both: the lean from its dx, the stretch from its dy
         _ (dx != 0 ? (pin me 'w (me 'w + dx * 7.0)))
         _ (dy != 0 ? (pin me 'sv (me 'sv - dy * 4.0)))
         word (? (dy < 0) ("you reach for the " + (0.0 < daylight (grass-hour g) ? "sun" "moon"))
                 (0 < dy) "you bow to the wind"
                 "")
         (pins g 'combo combo 'pts (g 'pts + combo) 'dk k 'dms now
                 'msg (word + (1 < combo ? ((word ? "   " "") + "combo x" + show combo) ""))))))

 ; ..and a tap is a place rather than a letter: the step it means is the direction from
 ; your blade's middle to the cell it landed on -- the nearest of the eight as the screen
 ; shows them, a cell being twice as tall as it is wide, so a tap a little off a row is
 ; still along it. c is [x y], cli's edtap, 0-based in screen order. a tap on the blade
 ; itself is nothing
 tap-keys {'(-1 0) 104 '(1 0) 108 '(0 -1) 107 '(0 1) 106
           '(-1 -1) 121 '(1 -1) 117 '(-1 1) 98 '(1 1) 110}
 (grass-tap g c now) (: me (g 'me) r (g 'r)
   n (int (me 'ht * rpi * (1.0 + me 's) + 0.5))
   ex (<c - me 'x)
   ey (<>c - (r - 4 - n // 2))
   ax (abs ex) ay (2 * abs ey)          ; in cell widths
   ; within 22.5 degrees of a row or a column is along it: tan is 5/12
   dx (12 * ax < 5 * ay ? 0 (toward 0 ex))
   dy (12 * ay < 5 * ax ? 0 (toward 0 ey))
   (dx = 0 && dy = 0 ? g (grass-key g (tap-keys [dx dy]) now)))

 ; --- one frame of the week -------------------------------------------------------
 (grass-tick g) (:
   c (g 'c) sb (g 'sb)
   h (: v (g 'h + dh) (v < week-hours ? v week-hours))
   fr (g 'fr + 1)
   t (fr * dt)
   day (grass-day g)
   ; the wind walks toward the day's own mean, the heading wanders, gusts ride three sines
   wt (? (fr % (fps * 60) = 1) (3.0 + roll sb 15) (g 'wt))
   wind (clamp (g 'wind + (roll sb 3 - 1) * 0.25 + (wt - g 'wind) * 0.003) 0.0 30.0)
   head ((g 'head + (roll sb 3 - 1) * 1.5 + 360.0) % 360.0)
   gust (1.0 + 0.3 * sin (t * 1.7) + 0.2 * sin (t * 4.3 + 1.0) + 0.15 * sin (t * 0.37))
   _ (pins g 'h h 'fr fr 'wt wt 'wind wind 'head head 'gust gust)
   hr (grass-hour g) dl (daylight hr) temp (grass-temp g)
   cover ((g 'covers) day)
   sun (dl * (1.0 - 0.6 * cover))              ; what reaches the ground
   ; the water: each tick a blade throws against the sky's thirst -- a chance in a
   ; thousand -- and loses a drop when it hits; the night gives some back a little at a
   ; time, and the dewfall before dawn a drink. nothing you do touches your water: the
   ; week's weather is the whole of it
   thirst (1000.0 * dry-rate * (0.05 + sun) * (1.0 + (temp - 60.0) / 50.0)
                  * (1.0 + wind / 30.0) * dh / dry-drop)
   dew ((1.0 - dl) * dew-rate * (1.0 - 0.5 * wind / 30.0) * clamp ((78.0 - temp) / 20.0) 0.2 1.0 * dh)
   fall (dew-hour <= hr && g 'dewday != day)
   drop (fall ? dew-drop 0.0)
   _ (fall ? (pins g 'dewday day 'msg "the dew falls"))
   ; once a day, at the day's own hour, the song: the cue is raised here and taken by
   ; whoever feeds the horn
   _ ((g 'songs) day <= hr && g 'sang != day ? (pins g 'sang day 'cue 1))
   ; growth wants water, warmth and light
   tf (: q ((temp - 72.0) / 32.0) v (1.0 - q * q) (v < 0.0 ? 0.0 v))
   (grow hy) (0.075 * clamp ((hy - 10.0) / 80.0) 0.0 1.0 * tf * (0.2 + 0.8 * sun) * dh)
   wx (grass-wind-x g * gust)
   ; each blade takes its own water, and is a spring in the wind: the push waves down
   ; the row, and a dry blade droops
   (blade b) (: lost (roll sb 1000 < thirst * b 'wf ? dry-drop 0.0)
                hy (clamp (b 'hy - lost + dew + drop) 0.0 100.0)
                _ (pin b 'hy hy)
                _ (g 'over ? () (pin b 'ht (b 'ht + grow hy * b 'gf)))
                f (wx * 0.8 * (1.0 + 0.35 * sin (t * 2.2 + b 'ph + b 'x * 0.3)))
                droop (hy < 25.0 ? (b 'dr * (1.0 - hy / 25.0)) 0.0)
                a (f - 16.0 * (b 'th - droop) - 3.0 * b 'w)
                w (b 'w + a * dt)
                ; ..and the stretch: a stiffer spring on the length, quick to settle
                sv (b 'sv - (40.0 * b 's + 5.0 * b 'sv) * dt)
                (pins b 'w w 'th (clamp (b 'th + w * dt) -1.3 1.3)
                        'sv sv 's (clamp (b 's + sv * dt) -0.6 0.35)))
   _ (each (g 'bs) blade)
   ; the clouds ride the steady wind, not the gusts: a drift that wobbled would step
   ; every cloud back and forth on its column
   _ (pin g 'drift (g 'drift + grass-wind-x g * dt * 0.12))
   ; seven days, and the week is over
   _ (h >= week-hours && !(g 'over) ? (pins g 'over 'done 'msg ""))
   g)

 ; --- the frame --------------------------------------------------------------------
 ; what stands on the sky and the dirt: [cells shade] -- cells is index -> [glyph fg bg],
 ; a bg of -1 taking the sky's own; shade the dirt indices a shadow falls on
 (grass-lay g) (:
   ov {} sh {} r (g 'r) c (g 'c) base (r - 4) top (r - 5)
   hr (grass-hour g) dl (daylight hr)
   sd (hr < 12.0 ? -1 1)                       ; the shadow's side: west of the blade till noon
   (put x y cl) (0 <= x < c && 1 <= y < r ? (pin ov (x + c * y) cl))
   (shade x y) (0 <= x < c ? (pin sh (x + c * y) 1))
   ; long at dawn and dusk, under the blade at noon, and none by night
   (shadow b) (: n (int (b 'ht * rpi + 0.5))
                 L (int (n * (1.0 - dl) * 1.3 + 1.0))
                 x0 (b 'x + round (b 'th * n * 0.4))
                 (go i) (i <= L ? (shade (x0 + sd * i) (base + 1),
                                   (i <= L // 2 ? (shade (x0 + sd * i) (base + 2))),
                                   go (i + 1)))
                 (0.15 < dl ? (go 1)))
   (blade b) (: n (: v (int (b 'ht * rpi * (1.0 + b 's) + 0.5)) (top < v ? top v))
                wilt (b 'hy < 12.0)
                ; a shortened blade bows out of line: a bulge along its length, on the
                ; side it already leans, that grows with the squeeze
                bow (b 's < -0.1 ? ((b 'th < 0.0 ? -6.0 6.0) * (-0.1 - b 's)) 0.0)
                (px k) (b 'x + round (b 'th * k * 0.8 + bow * sin (pi * k / (1 + n))))
                (cell k) (: x (px k) d (px (k + 1) - x)
                           gl (d @ 0 "┃" 1 "╱" "╲")
                           gi (clamp (int (dl * 3.0) + (b 'me ? 2 0) + ((k + b 'x) % 2)) 0 5)
                           fg (wilt ? (b 'me ? 178 142) (greens gi))
                           (put x (base - k) [gl fg -1]))
                (go k) (k < n ? (cell k, go (k + 1)))
                (go 0))
   ; the rest first: you are painted over them
   _ (each (g 'bs) (b \ (b 'me ? () (shadow b, blade b))))
   _ (: me (g 'me) (shadow me, blade me))
   [ov sh])

 ; the clouds of the day as a tablet of sky index -> depth, 3 at the core down to 0 at
 ; the edge: the cover picks how many show, each an ellipse on the drift, flatter under
 ; than over, its edge dithered, its underside a shade darker, and a little noise
 ; through the whole of it. where two overlap the deeper one shows
 (grass-clouds g) (:
   cm {} r (g 'r) c (g 'c)
   n (3 + int (((g 'covers) (grass-day g)) * 10.0))
   drift (g 'drift)
   (deep k v) (: o (peep cm k -1) (o < v ? (pin cm k v)))
   ; a cloud sits on a whole column and is tested by whole columns, so nothing at its
   ; edge moves until the whole of it steps; the noise and the dither are keyed to the
   ; cloud's own columns, so they step with it
   (lay cl) (: cx (((int (cl 'x0 + drift)) + 2 * c) % c) w (cl 'w) hh (cl 'h) cy (cl 'y)
               k0 (int (cl 'x0 - w) - 2)                 ; the cloud's own first column
               (row y x) (x <= cx + w ?
                          (: dx ((x - cx) / w) dy ((y - cy) / hh * (cy < y ? 1.7 1.0)) e (dx * dx + dy * dy)
                             xx ((x + 2 * c) % c)
                             kx (x - int (cx - w) + k0)
                             v (3 - int (e * 3.0) - (cy < y) - (0 = dice kx y 5 4))
                             _ (? (e < 1.0) (deep (xx + c * y) (v < 0 ? 0 v))
                                  (e < 1.3 && 0 = dice kx y 9 3) (deep (xx + c * y) 0)
                                  ())
                           (row y (x + 1))))
               (rows y) (y <= cy + hh ? (1 <= y ? (row y (int (cx - w) - 2)), rows (y + 1)))
               (rows (int (cy - hh))))
   _ (each (first-n n (g 'clouds)) lay)
   cm)

 (grass-frame g) (:
   j (jug 0) r (g 'r) c (g 'c) base (r - 4)
   hr (grass-hour g) dl (daylight hr)
   ls (grass-lay g) ov <ls sh <>ls
   cm (grass-clouds g)
   skybg (sky-pen hr)
   dark (dl = 0.0 && (hr < 5.5 || 20.5 < hr))
   cb (? (0.6 < dl) 255 (0.05 < dl) 217 240)  ; the clouds' own: lit, and in shade
   cd (? (0.6 < dl) 252 (0.05 < dl) 181 237)
   ; ..and a little brighter where the sun or the moon is behind them: a glow, not a disc
   cbl (? (0.6 < dl) 231 (0.05 < dl) 223 252)
   cdl (? (0.6 < dl) 255 (0.05 < dl) 224 246)
   ; a cloud cell by depth: solid at the core, shaded blocks toward the edge; one lit
   ; from behind keeps its depth and wears the lit pens
   (cloud-cell v lit) (: b (lit ? cbl cb) d (lit ? cdl cd)
                         (v @ 3 ["█" b b] 2 ["▓" b d] 1 ["▒" d skybg] ["░" d skybg]))
   ; the sun by day and the moon by night, east to west
   mh (dl > 0.0 ? hr ((hr + 12.0) % 24.0)) ml (daylight mh)
   sx (c - 3 - int ((mh - 6.0) / 12.0 * (c - 4)))
   sy (clamp (1 + int ((r - 7) * (1.0 - ml))) 1 (base - 1))
   sp (dl > 0.0 ? 220 252)
   dirt (? (0.3 < dl) dirt-day (0.05 < dl) dirt-dusk dirt-night)    ; the dirt by light
   dots (? (0.3 < dl) dot-day (0.05 < dl) dot-dusk dot-night)
   ; the sky behind a cell: a cloud over the sun, the moon and the stars
   (sky x y i) (: cl (peep cm i -1)
                  (? (0 <= cl) (cloud-cell cl (y = sy && -1 <= x - sx <= 2))
                     (y = sy && (x = sx || x = sx + 1)) [" " sp sp]
                     (dark && 0 = dice x y 7 53) [(twinkles ((dice x y 11 3 + (g 'fr // 9)) % 3)) 230 skybg]
                     [" " skybg skybg]))
   (cell x y) (: i (x + c * y) o (peep ov i ())
     (? (base < y) (: s (peep sh i 0)
                        ; patches four cells wide, a dot of its own on each
                        [(dirt-dots (dice x y 3 4)) (s ? 94 (dots (dice x y 17 #dots))) (s ? 58 (dirt (dice (x // 4) y 13 #dirt)))])
        (two? o) [(o 0) (o 1) (o 2 < 0 ? ((sky x y i) 2) (o 2))]
        (sky x y i)))
   (row y x f b) (x < c ? (: cl (cell x y) f2 (cl 1) b2 (cl 2)
                            _ (f2 != f || b2 != b ? (say j (sgr f2 b2)))
                            _ (say j (cl 0))
                            (row y (x + 1) f2 b2)))
   ; a row is painted to the screen's edge, so it wants no erase after it: under a
   ; pending wrap an erase takes the very glyph that raised it, and the last column
   ; would go blank
   (rows y) (y < r ? (row y 0 -1 -1, say j (esc + "[0m\r\n"), rows (y + 1)))
   _ (say j (esc + "[H" + esc + "[0m" + fit (grass-hud g) c + "\r\n"))
   _ (rows 1)
   ; the bar a column short of the screen, so a wrapping console never scrolls the
   ; field -- and its erase falls on that spare column, where it costs nothing
   _ (say j (esc + "[0m" + fit (grass-bar g) (c - 1) + esc + "[K"))
   (slurp j))

 ; the day and the weather to the left, what is yours to the right, the screen's spare
 ; cells between them
 (grass-hud g) (: hr (grass-hour g) hh (int hr) mm (int ((hr - hh) * 60.0)) d (int (g 'h / 24.0))
   l (day-names (d % 7) + " " + two-dig hh + ":" + two-dig mm
      + "  " + show (round (grass-temp g)) + "°F  " + show (round (g 'wind)) + " kt " + compass (g 'head))
   r (fx1 (g 'me 'ht) + "\"  H2O " + show (round (g 'me 'hy)) + "%  score " + show (g 'pts))
   gap (: n (g 'c - wide l - wide r) (n < 2 ? 2 n))
   (l + (gap (t \ t + " ") "") + r))
 (grass-bar g) (? (g 'me 'hy < 12.0) ("you are wilting  " + g 'msg)
                  (g 'msg || "dance: arrows or hjkl, fast and changing   q leaves"))
 (grass-final g) (g 'over = 'done ? ("seven days: " + show (g 'pts) + " points, " + fx1 (g 'me 'ht) + " in tall")
                                    ("you left the field on day " + show (1 + grass-day g)))

 ; --- the song: a music box out the horn, wind chimes between its plays ---------------
 (grass-tune ls) (score-tune (filter (b \ !(b 'err)) (score-parse ls)) song-cps)
 chime-ring 3.0
 ; the song's state over a horn h: the tune and how many bars it runs, the pitches the
 ; chimes may ring, a die of its own. mode is 'chimes or 'song; a cue starts the song at
 ; the write head, and when its last bar is scheduled the chimes come back under it
 (grass-song-new bs h st)                  ; st is a wheel: a bare number rolls nothing
  (: ps (foldl (\ acc b (foldl (\ a p (elem p a ? a (p . a))) acc (b 'pitches))) () bs)
   {'tune (score-tune bs song-cps) 'bars #bs 'set (sort ps) 'sb {st} 'h h
    'fpos 0 'cyc 0 'next 0 'vs () 'mode 'chimes 'chimes 1})
 (grass-song-cue s) (pins s 'mode 'song 'cyc 0 'next (s 'fpos))
 ; chimes a second: a few in a calm, many in a blow
 (chime-rate wind) (0.25 + wind / 8.0)
 ; one bar's onsets as [start voice], the bar starting at frame st and spc frames long
 (song-voices s c st spc)
  (filter two? (map (\ x (: at (st + int (spc * qnum (evwb x - qi c)))
                           v (mkvoice at (evv x) song-rate)
                         (two? v ? [at v])))
                    (filter onset? ((s 'tune) (qi c) (qi (c + 1))))))
 ; one chunk out the horn, for the wind that blows now. the write is also the clock: the
 ; card takes a chunk at the rate it plays one, so the frame loop that feeds it needs no
 ; rest of its own
 (grass-song-feed s wind)
  (: spc (int (song-rate / song-cps))
     (sched _) (? (s 'mode = 'song && s 'next <= s 'fpos + song-chunk && s 'cyc < s 'bars)
                  (: _ (pin s 'vs (cat (s 'vs) (song-voices s (s 'cyc) (s 'next) spc)))
                     _ (pins s 'cyc (s 'cyc + 1) 'next (s 'next + spc))
                   (sched ())))
     _ (sched ())
     _ (s 'mode = 'song && s 'bars <= s 'cyc ? (pin s 'mode 'chimes))
     base (s 'fpos)
     ; a chime, now and then, off the score's own notes, two octaves up: the die against
     ; the wind's rate per chunk, in thousandths
     sb (s 'sb)
     _ (? (s 'chimes && s 'mode = 'chimes && two? (s 'set)
           && roll sb 1000 < int (chime-rate wind * 1000.0 / 30.0))
          (: at (base + roll sb song-chunk)
             nt ((s 'set) (roll sb #(s 'set)))
             v (mkvoice at {'s "chime" 'note nt 'gain (0.1 + roll sb 25 / 100.0)
                             'pan (roll sb 100 / 100.0) 'legato chime-ring} song-rate)
             (pin s 'vs (cat (s 'vs) [[at v]]))))
     live (filter (p \ p 1 0 >= base) (s 'vs))          ; not finished
     now (filter (p \ p 0 < base + song-chunk) live)    ; ..and already begun
     vs (map (p \ p 1) now)
     _ (pins s 'vs live 'fpos (base + song-chunk))
   (say (s 'h) (pack (mixdown vs base song-chunk) song-chunk song-gain)))

 ; --- the week on the tty ------------------------------------------------------------
 ; the clock paces the ticks, thirty a second, and the horn is fed by its lag: chunks go
 ; out until a lead stands queued, ahead of anything else the loop does. a frame is
 ; painted only when the tick it shows is on time -- a seat too slow to draw every tick
 ; (the page draws one in forty milliseconds) still ticks at the clock's rate and still
 ; sounds, and gives up frames rather than either.
 song-lead (6 * song-chunk)                             ; queued ahead: a fifth of a second
 song-lead-max (20 * song-chunk)                        ; ..and at most this, the ring holding a second
 tick-ms (1000.0 / fps)
 ; a sign stands deaf for half a second, then waits for a key; the song plays under it
 ; either way, since a beat is what feeds the horn. deaf by the clock and not by beats:
 ; a card takes its first chunks at once, so the beats say nothing about the time
 sign-deaf 500                                          ; ms a sign is deaf for
 (sign g ttl rows beat) (: _ (say out (sign-over (grass-frame g) ttl rows 0 (g 'r) (g 'c)), flush out)
                           t0 (clock 0)
                           (deaf _) (clock t0 < sign-deaf ? (drain-keys (), beat (), deaf ()))
                           (wait _) (cue? 0 ? (edkey in) (beat (), wait ()))
                           _ (deaf ())
                           (wait ()))
 (grass-week ls) (: ws (tty 1)
   r (two? ws && 7 < <ws ? (<ws - 1) 23)
   c (two? ws && 19 < <>ws ? <>ws 80)
   g (grass-new r c (wheel (clock 0)))
   bs (filter (b \ !(b 'err)) (score-parse ls))
   hn (? bs (: h (horn song-rate 2) (? (nom? h) () h)) ())
   sng (? hn (grass-song-new bs hn (wheel (clock 0))) ())
   ; THE QUEUE MUST OUTLAST THE GAP BETWEEN FEEDS, and on a slow seat that gap is one
   ; frame's painting: a fifth of a second is a desktop's answer and a phone's silence.
   ; so the gap is measured, held at its recent worst -- halving every two seconds, by
   ; the clock and not by calls -- and the lead follows it
   pace {'t (clock 0) 'gap 0.0}
   (pace! _) (: t (clock 0)
                d (1.0 * (t - pace 't))
                v ((d / 2000.0) 0.5 * pace 'gap)
                _ (pins pace 't t 'gap (v < d ? d v))
                (pace 'gap))
   (lead _) (: n (int (2.5 * pace! () * song-rate / 1000.0))
               (n < song-lead ? song-lead (song-lead-max < n ? song-lead-max n)))
   (feed _) (: l (lead ())
               (fill _) (? (sng && horn-lag hn < l) (grass-song-feed sng (g 'wind), fill ()) ())
               (fill ()))
   (beat _) (feed (), rest 5)                           ; a sign's idle: the lead, then a breath
   (cue _) (? (sng && g 'cue) (grass-song-cue sng, pin g 'cue 0))
   ; tick n is owed at t0 + n ticks. behind by a whole tick, the frame is skipped and the
   ; tick alone catches up; behind by many (a sign stood, the tab slept) the clock is
   ; re-based instead, so no stretch of the week runs in fast forward
   (swim n) (? (g 'over) ()
     (: _ (feed ())
        due (g 't0 + n * tick-ms)
        late (clock 0 - due)
        (? (late < 0.0) (rest 2, swim n)
           (: _ (? (10.0 * tick-ms < late) (pin g 't0 (g 't0 + late)))
              _ (key-drain g repeat-gap (k \ (k = -12 ? (grass-tap g (edtap ()) (clock 0))
                                                          (grass-key g k (clock 0)))))
              _ (grass-tick g)
              _ (cue ())
              _ (? (late < tick-ms) (say out (grass-frame g), flush out) ())
              (swim (n + 1))))))
   _ (say out (esc + "[?25l"))
   _ (sign g open-ttl open-rows beat)
   _ (pin g 't0 (clock 0))
   _ (swim 0)
   _ (? (g 'over = 'done)
        (pin g 'cue 1, cue (),
         sign g end-ttl ["" ("final score   " + show (g 'pts))
                         ("final height  " + fx1 (g 'me 'ht) + " in") "" "-- any key --"] beat)
        ())
   _ (? hn (: _ (flush hn) (close hn)) ())
   g)
 ; the screen raised and put back here; a terminal is asked for its taps too (xterm's
 ; SGR mouse reports, which cli's edkey reads as the key -12)
 (grass-run ls) (: _ (raw 1)
                  _ (say out (esc + "[?1049h" + esc + "[2J" + esc + "[?1000h" + esc + "[?1006h"))
                  g (grass-week ls)
                  _ (say out (esc + "[?1006l" + esc + "[?1000l" + esc + "[0m" + esc + "[?25h" + esc + "[?1049l"))
                  _ (flush out)
                  _ (drain-keys ())
                  _ (raw 0)
                  (puts (grass-final g + "\n"), 0))
 grass-usage "usage: love grass   (dance: arrows, hjkl, or tap about your blade; q or esc leaves)"
 (grass-main as) (as @ () (grass-run score)
                       (say err ("grass: " + grass-usage + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'grass (udoor 'grass grass-main grass-usage 1 1)))
) ; module grass
