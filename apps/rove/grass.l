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
         grass-tune grass-song-new grass-song-feed grass-final
         daylight sky-pen compass fx1 week-hours dh fps dance-cost)
(borrow 'rove)
; harp and play are optional the way posix is: a seat without them plays in silence
(? (tablet? (cite 'harp)) (borrow 'harp) ())
(? (tablet? (cite 'play)) (borrow 'play) ())
(? (cite 'posix) (borrow 'posix) ())
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
 dance-cost 0.3                         ; water a press costs, in points of a hundred
 dew-hour 5.0                           ; the dewfall: just before dawn, every blade drinks
 dew-drop 20.0

 ; the tune: bars of harp's mini-notation, semitones from middle c, and a bass note a bar
 bars '("11 9 7 4" "7 [9 7] 4 ~" "11 9 7 2" "4 [2 0] -1 ~"
        "4 7 11 16" "14 [11 14] 9 ~" "7 [9 11] 7 4" "2 [4 2] -5 ~")
 bass '(-8 -8 -10 -12 -8 -3 -5 -8)
 song-rate (love-arch = 'wasm ? 16000 48000)
 song-cps 0.32                          ; bars a second: a music box wound down
 song-chunk (song-rate // 30)           ; a frame's worth, thirty a second
 song-gain 7000.0

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
 open-rows '("you are a blade of grass. you have one week."
             ""
             "dance with the arrow keys (or hjkl): quick presses on"
             "changing keys are a combo, and the combo is the points."
             "dancing costs water. dew comes on calm cool nights; the"
             "sun and the wind take it by day. water and warmth grow you."
             ""
             "q or esc leaves."
             ""
             "-- any key --")
 end-ttl "seven days"

 (clamp x lo hi) (x < lo ? lo (hi < x ? hi x))
 (round x) (int (x + (x < 0.0 ? -0.5 0.5)))
 (fx1 x) (: n (int (x * 10.0 + 0.5)) (show (n // 10) + "." + show (n % 10)))
 (two-dig n) (n < 10 ? ("0" + show n) (show n))
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
              'ph (roll sb 628 / 100.0) 'gf (0.6 + roll sb 50 / 100.0)
              'dr (roll sb 2 ? 0.8 -0.8) 'me 0}
   bs (map blade ^n)
   me (bs (n // 2))
   _ (pins me 'me 1 'ht 2.0 'gf 1.0)
   tdays (map (\ _ (52.0 + roll sb 26)) ^7)
   covers (map (\ _ (roll sb 10 / 10.0)) ^7)
   clouds (map (\ _ {'x0 (roll sb c * 1.0) 'y (1 + roll sb (r // 2))
                     'w (6.0 + roll sb 13) 'h (1.2 + roll sb 19 / 10.0)}) ^14)
   {'r r 'c c 'h week-start 'fr 0 'sb sb 'bs bs 'me me 'tdays tdays 'covers covers 'clouds clouds
    'wind (3.0 + roll sb 10) 'wt 8.0 'head (roll sb 360 * 1.0) 'gust 1.0 'drift 0.0
    'hy 80.0 'fh 80.0 'dewday 0 'pts 0 'combo 0 'dk 0 'dms 0 'lk 0 'lt 0 'over 0 'msg ""})

 ; --- the helm: an arrow or hjkl pushes your blade, q or esc leaves ---------------
 ; a press within the gap of the last, on another key, grows the combo; the combo
 ; is the points. sideways is a shove; up is a reach, into the bend, down a bow against it
 (grass-key g k now) (: mv (steer k) me (g 'me)
   (? (g 'over) g
      (k @ (113 || 27) 1 0) (pins g 'over 'fled 'msg "")
      (one? mv) g
      (: dx <mv dy <>mv
         push (? (dx != 0) (dx * 7.0) (me 'th >= 0.0 ? (dy * -5.0) (dy * 5.0)))
         combo (? (k != g 'dk && (now - g 'dms) < dance-gap) (1 + g 'combo) 1)
         _ (pin me 'w (me 'w + push))
         word (? (dy < 0) ("you reach for the " + (0.0 < daylight (grass-hour g) ? "sun" "moon"))
                 (0 < dy) "you bow to the sky"
                 "")
         (pins g 'combo combo 'pts (g 'pts + combo) 'dk k 'dms now
                 'hy (clamp (g 'hy - dance-cost) 0.0 100.0)
                 'msg (word + (1 < combo ? ((word ? "   " "") + "combo x" + show combo) ""))))))

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
   ; the water: the sun and the wind take it, a calm cool night gives some back, and
   ; the dewfall before dawn gives every blade a drink
   evap (2.2 * (0.05 + sun) * (1.0 + (temp - 60.0) / 50.0) * (1.0 + wind / 30.0))
   dew (? (dl > 0.0 || 12.0 <= wind || 72.0 <= temp) 0.0
          (4.0 * (1.0 - wind / 12.0) * clamp ((72.0 - temp) / 15.0) 0.0 1.0))
   fall (dew-hour <= hr && g 'dewday != day)
   dw ((dew - evap) * dh + (fall ? dew-drop 0.0))
   _ (pins g 'fh (clamp (g 'fh + dw) 0.0 100.0) 'hy (clamp (g 'hy + dw) 0.0 100.0))
   _ (fall ? (pins g 'dewday day 'msg "the dew falls"))
   ; growth wants water, warmth and light
   tf (: q ((temp - 72.0) / 32.0) v (1.0 - q * q) (v < 0.0 ? 0.0 v))
   (grow hy) (0.075 * clamp ((hy - 10.0) / 80.0) 0.0 1.0 * tf * (0.2 + 0.8 * sun) * dh)
   wx (grass-wind-x g * gust)
   ; a spring in the wind: the push waves down the row, and a dry blade droops
   (blade b) (: hy (b 'me ? (g 'hy) (g 'fh))
                _ (g 'over ? () (pin b 'ht (b 'ht + grow hy * b 'gf)))
                f (wx * 0.8 * (1.0 + 0.35 * sin (t * 2.2 + b 'ph + b 'x * 0.3)))
                droop (hy < 25.0 ? (b 'dr * (1.0 - hy / 25.0)) 0.0)
                a (f - 16.0 * (b 'th - droop) - 3.0 * b 'w)
                w (b 'w + a * dt)
                (pins b 'w w 'th (clamp (b 'th + w * dt) -1.3 1.3)))
   _ (each (g 'bs) blade)
   _ (pin g 'drift (g 'drift + wx * dt * 0.12))
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
   (blade b) (: n (: v (int (b 'ht * rpi + 0.5)) (top < v ? top v))
                hy (b 'me ? (g 'hy) (g 'fh))
                wilt (hy < 12.0)
                (px k) (b 'x + round (b 'th * k * 0.8))
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
   (lay cl) (: cx ((cl 'x0 + drift) % c) w (cl 'w) hh (cl 'h) cy (cl 'y)
               (row y x) (x <= cx + w ?
                          (: dx ((x - cx) / w) dy ((y - cy) / hh * (cy < y ? 1.7 1.0)) e (dx * dx + dy * dy)
                             xx ((int (x + 2 * c)) % c)
                             v (3 - int (e * 3.0) - (cy < y) - (0 = dice xx y 5 4))
                             _ (? (e < 1.0) (deep (xx + c * y) (v < 0 ? 0 v))
                                  (e < 1.3 && 0 = dice xx y 9 3) (deep (xx + c * y) 0)
                                  ())
                           (row y (x + 1.0))))
               (rows y) (y <= cy + hh ? (1 <= y ? (row y (cx - w - 1.0)), rows (y + 1)))
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
   (rows y) (y < r ? (row y 0 -1 -1, say j (esc + "[0m" + esc + "[K\r\n"), rows (y + 1)))
   _ (say j (esc + "[H" + esc + "[0m" + fit (grass-hud g) c + esc + "[K\r\n"))
   _ (rows 1)
   ; the bar a column short of the screen, so a wrapping console never scrolls the field
   _ (say j (esc + "[0m" + fit (grass-bar g) (c - 1) + esc + "[K"))
   (slurp j))

 (grass-hud g) (: hr (grass-hour g) hh (int hr) mm (int ((hr - hh) * 60.0)) d (int (g 'h / 24.0))
   ("day " + show (1 + d) + " " + day-names (d % 7) + " " + two-dig hh + ":" + two-dig mm
    + "  " + show (round (grass-temp g)) + "°F  wind " + show (round (g 'wind)) + " kt " + compass (g 'head)
    + "  height " + fx1 (g 'me 'ht) + " in  water " + show (round (g 'hy)) + "%  points " + show (g 'pts)))
 (grass-bar g) (? (g 'hy < 12.0) ("you are wilting  " + g 'msg)
                  (g 'msg || "dance: arrows or hjkl, fast and changing   q leaves"))
 (grass-final g) (g 'over = 'done ? ("seven days: " + show (g 'pts) + " points, " + fx1 (g 'me 'ht) + " in tall")
                                    ("you left the field on day " + show (1 + grass-day g)))

 ; --- the song: a music box out the horn ------------------------------------------
 (grass-tune _) (: mel (slowcat (map (b \ pset (note (mini b)) (legato (pure 1.3))) bars))
                   low (slowcat (map (n \ pset (pset (note (pure n)) (legato (pure 2.2)))
                                                (gain (pure 0.6)))
                                     bass))
                   (stack [mel low]))
 ; a struck tine: the note, a partial an octave and a fifth up that dies fast, a bright
 ; one that dies faster, and the long ring under them. an octave up: a music box is small
 (box-voice st v rate) (:
   dur (vnum v 'legato 1.3)
   nt (vnum v 'note (vnum v 'n 0))
   f (523.2511306011972 * exp (nt * ln2-12))
   amp (vnum v 'gain 1.0)
   end (st + int (dur * rate) + 2)
   fn (\ ix (: t ((ix - st) * (1.0 / rate))
               tp (t * (t > 0.0))
               w (tp * tau * f)
               ((sin w + 0.3 * sin (w * 3.0) * exp (tp * -6.0) + 0.15 * sin (w * 5.8) * exp (tp * -9.0))
                * (1.0 - exp (tp * -900.0)) * exp (tp / dur * -3.5) * (t < dur))))
   [end fn (amp * 0.5) (amp * 0.5)])
 (grass-song-new tune h) {'tune tune 'h h 'fpos 0 'cyc 0 'next 0 'vs ()}
 ; one bar's onsets as [start voice], the bar starting at frame st and spc frames long
 (song-voices s c st spc)
  (filter two? (map (\ x (: at (st + int (spc * qnum (evwb x - qi c)))
                           v (box-voice at (evv x) song-rate)
                         (two? v ? [at v])))
                    (filter onset? ((s 'tune) (qi c) (qi (c + 1))))))
 ; one chunk out the horn. the write is also the clock: the card takes a chunk at the
 ; rate it plays one, so the frame loop that feeds it needs no rest of its own
 (grass-song-feed s)
  (: spc (int (song-rate / song-cps))
     (sched _) (? (s 'next <= s 'fpos + song-chunk)
                  (: _ (pin s 'vs (cat (s 'vs) (song-voices s (s 'cyc) (s 'next) spc)))
                     _ (pins s 'cyc (s 'cyc + 1) 'next (s 'next + spc))
                   (sched ())))
     _ (sched ())
     base (s 'fpos)
     live (filter (p \ p 1 0 >= base) (s 'vs))          ; not finished
     now (filter (p \ p 0 < base + song-chunk) live)    ; ..and already begun
     vs (map (p \ p 1) now)
     _ (pins s 'vs live 'fpos (base + song-chunk))
   (say (s 'h) (pack (mixdown vs base song-chunk) song-chunk song-gain)))

 ; --- the week on the tty ------------------------------------------------------------
 ; keys drained per frame, a frame painted, a chunk of song out (or a beat's rest)
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
 (grass-week _) (: ws (tty 1)
   r (two? ws && 7 < <ws ? (<ws - 1) 23)
   c (two? ws && 19 < <>ws ? <>ws 80)
   g (grass-new r c (wheel (clock 0)))
   tune (? (tablet? (cite 'harp)) (grass-tune ()) ())
   hn (? tune (: h (horn song-rate 2) (? (nom? h) () h)) ())
   sng (? hn (grass-song-new tune hn) ())
   (beat _) (? sng (grass-song-feed sng) (rest 33))
   (swim _) (? (g 'over) ()
               (: _ (key-drain g repeat-gap (k \ grass-key g k (clock 0)))
                  _ (grass-tick g)
                  _ (say out (grass-frame g), flush out)
                  _ (beat ())
                  (swim ())))
   _ (say out (esc + "[?25l"))
   _ (sign g open-ttl open-rows beat)
   _ (swim ())
   _ (? (g 'over = 'done)
        (sign g end-ttl ["" ("final score   " + show (g 'pts))
                         ("final height  " + fx1 (g 'me 'ht) + " in") "" "-- any key --"] beat)
        ())
   _ (? hn (: _ (flush hn) (close hn)) ())
   g)
 (grass-run _) (: _ (raw 1)
                  _ (say out (esc + "[?1049h" + esc + "[2J"))
                  g (grass-week ())
                  _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"))
                  _ (flush out)
                  _ (drain-keys ())
                  _ (raw 0)
                  (puts (grass-final g + "\n"), 0))
 grass-usage "usage: love grass   (dance: arrows or hjkl; q or esc leaves)"
 (grass-main as) (two? as ? (say err ("grass: " + grass-usage + "\n"), flush err, 2) (grass-run ()))
 _ (pins (cite 'verbs 'tab) 'grass (udoor 'grass grass-main grass-usage 1 1)))
) ; module grass
