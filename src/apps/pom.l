; pom -- the phase of the moon, after the bsd game by way of pcal's arithmetic. utc,
; the hour its finest grain, as the original.
;   pom          the moon now, one line
;   pom -e       the date, the phase and the moon drawn to the terminal
;   pom -d       every hour of the month; with -e, redrawn in place
;   pom -p [N]   the moon now, N pixels square in half-blocks
;   pom -s [N]   the moon now as the pom saver draws it, its seas and dark limb
;   pom -n [N]   the moon now drawn naturally: lit as the moon scatters sunlight, its seas
;                soft, tycho and copernicus bright, earthshine on the dark side
;   pom [[[[[cc]yy]mm]dd]HH]  another hour, date(1)'s order
; usage: love pom [-d] [-e] [[[[[[cc]yy]mm]dd]HH]] | -p [N] | -s [N] | -n [N]
(module (pom pom-main pom-julian pom-phase pom-name pom-percent pom-art
             pom-pixels pom-now pom-cells pom-tint pom-tc pom-xterm pom-lit
             pom-lit? pom-mare? pom-face pom-moon pom-glow pom-natural)
(borrow 'cal)
(:
 epoch 2444238.5                       ; 1980 january 0.0
 elonge 278.833540                     ; the sun's ecliptic longitude at the epoch
 elongp 282.596403                     ; ... and at perigee
 eccent 0.01671542                     ; the earth's orbit
 mmlong 64.975464                      ; the moon's mean longitude at the epoch
 mmlongp 349.383063                    ; ... and of its perigee
 (rad d) (d * pi / 180)
 (deg r) (r * 180 / pi)
 (fixangle a) (a - 360 * floor (a / 360))

 ; the julian day at noon's start of m/d/y; before 1582-10-15 the julian calendar
 (pom-julian m d y)
  (: y1 (y < 0 ? (y + 1) y)
     jm (m < 3 ? (m + 12) m)
     jy (m < 3 ? (y1 - 1) y1)
     b (y < 1582 || y = 1582 && (m < 10 || m = 10 && d < 15) ? 0
          (floor (jy / 100) @ a (2 - a + floor (a / 4))))
     c ((jy < 0 ? (floor (365.25 * jy - 0.75)) (floor (365.25 * jy))) - 694025)
     (b + c + floor (30.6001 * (jm + 1)) + d + 2415020))

 ; the eccentric anomaly, kepler's equation by newton's method; m in degrees
 (kepler m0 ecc)
  (: m (rad m0)
     (go e) (: dl (e - ecc * sin e - m) e2 (e - dl / (1 - ecc * cos e))
               (abs dl > 0.000001 ? (go e2) e2))
     (go m))

 ; the moon's age as a fraction of a circle: 0 new, 0.25 first quarter, 0.5 full
 (pom-phase h m d y)
  (: day (pom-julian m d y + h / 24.0 - epoch)
     n (fixangle (360 / 365.2422 * day))
     msun (fixangle (n + elonge - elongp))
     ec (kepler msun eccent)
     lsun (fixangle (2 * deg (atan (sqrt ((1 + eccent) / (1 - eccent)) * tan (ec / 2))) + elongp))
     ml (fixangle (13.1763966 * day + mmlong))
     mm (fixangle (ml - 0.1114041 * day - mmlongp))
     ev (1.2739 * sin (rad (2 * ml - lsun) - mm))
     ae (0.1858 * sin (rad msun))
     a3 (0.37 * sin (rad msun))
     mmp (mm + ev - ae - a3)
     mec (6.2886 * sin (rad mmp))
     a4 (0.214 * sin (rad (2 * mmp)))
     lp (ml + ev + mec - ae - a4)
     v (0.6583 * sin (rad (2 * (lp - lsun))))
     (fixangle (lp + v - lsun) / 360))

 ; how much is lit, 0 to 100, and its name; waxing is judged at two places, as printed
 (pom-percent p) (int ((p * 360 - 180) / 180 * 100) @ k (k < 0 ? (100 + k) (100 - k)))
 (pom-name p)
  (: k (pom-percent p)
     wax (floor (p * 100 + 0.5) < 50)
     (? (k < 2) "New"
        (k > 99) "Full"
        (k = 50) (wax ? "First Quarter" "Last Quarter")
        (k < 50) (wax ? "Waxing Crescent" "Waning Crescent")
        (wax ? "Waxing Gibbous" "Waning Gibbous")))

 ; the moon drawn w columns by h rows, three lines of text at its left
 surface ":-+=*O08#@"
 (rep c n) (n < 1 ? "" (n (s \ s + c) ""))
 (pom-art p w h date)
  (: rot ((p * 360 - 180) / 180)
     inc (2 / h)
     texts [("Date : " + date) ("Phase: " + pom-name p) ("Full : " + show (pom-percent p) + "%")]
     (line y k)
      (: x (sqrt (1 - y * y))
         ms0 (int (x * w * 5 / 7))
         ms (ms0 & 1 ? (ms0 - 1) ms0)
         sp (int ((w - ms) / 2))
         t (k < 3 ? (texts k) "")
         dark (ms * abs rot)
         light (ms - dark)
         term (string (surface (int ((light - floor light) * 10))))
         ds (rep ":" (int dark))
         ls (rep "@" (int light))
         (t + rep " " (sp - #t) + (rot < 0 ? (ds + term + ls) (ls + term + ds)) + "\n"))
     (go y k) (y > -1 ? (line y k + go (y - inc) (k + 1)) "")
     (go (1 - inc / 2) 0))

 ; --- pixels -----------------------------------------------------------------------
 ; the moon n by n at phase p: the lit side on the right waxing, the left waning, the
 ; dark limb dim so a new moon is still a disc, () outside it
 pom-lit 0xffd787
 pom-dim 0x4e4e4e
 (pom-pixels p n)
  (: k (cos (2 * pi * p))
     (px i j) (: x ((j + 0.5) * 2 / n - 1) y ((i + 0.5) * 2 / n - 1) w (sqrt (1 - y * y))
                 (? (1 < x * x + y * y) ()
                    (p < 0.5 ? (w * k < x) (x < 0 - w * k)) pom-lit
                    pom-dim))
     (map (i \ map (j \ px i j) ^n) ^n))
 ; lit at (nx ny) on the unit disc: the terminator is an ellipse cos 2πp wide, waxing
 ; lights the right side and waning the left
 (pom-lit? p nx ny) (: s (sqrt (max 0.0 (1.0 - ny * ny))) k (cos (2 * pi * p))
                      (p < 0.5 ? (nx > k * s) (nx < 0 - k * s)))
 ; the seas, roughly where they lie: [x y radius] on the unit disc, north up
 maria [[-0.35 -0.45 0.28] [0.18 -0.38 0.17] [0.3 -0.05 0.2] [0.68 -0.3 0.12]
        [-0.6 0.0 0.35] [-0.2 0.45 0.18] [0.55 0.2 0.14]]
 (pom-mare? nx ny) (any (m \ ((nx - m 0) * (nx - m 0) + (ny - m 1) * (ny - m 1) < m 2 * m 2)) maria)
 ; the saver's moon at (nx ny): an xterm pen, sea or highland lit, the limb dark, () off it
 (pom-face p nx ny) (? (1.0 < nx * nx + ny * ny) ()
                      (pom-lit? p nx ny) (pom-mare? nx ny ? 187 230)
                      234)
 ; ..and n by n of it as rgb, for pom-cells
 (pom-moon p n) (: (px i j) (pom-face p ((j + 0.5) * 2 / n - 1) ((i + 0.5) * 2 / n - 1)
                              @ k (charm? k ? (xrgb k)))
                   (map (i \ map (j \ px i j) ^n) ^n))
 ; --- the moon drawn naturally: the sun's way by the phase (behind at new, round the right
 ; through the first quarter, from the eye at full); lit as the moon scatters it -- lommel
 ; and seeliger's law, which leaves a full moon nearly flat to its limb -- with a little
 ; lambert; the seas soft-edged and bluer, the highlands mottled, tycho and copernicus
 ; bright and tycho's rays faint; earthshine on the dark side, most near new; the light
 ; toned as the sky's is. rgb as 0xrrggbb at (nx ny) on the unit disc, () off it ---
 craters [[-0.12 0.64 0.05 0.5] [-0.33 0.06 0.04 0.3] [0.42 -0.38 0.03 0.25]]
 ; the seas, north up: the saver's maria and nectaris beside them
 seas [[-0.35 -0.45 0.28] [0.18 -0.38 0.17] [0.3 -0.05 0.2] [0.68 -0.3 0.12]
       [-0.6 0.0 0.35] [-0.2 0.45 0.18] [0.55 0.2 0.14] [0.38 0.32 0.09]]
 (sat v) (v < 0.0 ? 0.0 (1.0 < v ? 1.0 v))
 (pom-glow p nx ny)
  (: d2 (nx * nx + ny * ny)
     (? (1.0 < d2) ()
        (: nz (sqrt (1.0 - d2)) a (2 * pi * p) sx (sin a) sz (0.0 - cos a)
           mu0 (nx * sx + nz * sz) mu nz
           ls (mu0 <= 0.0 ? 0.0 (mu0 / (mu0 + mu)))
           lit (1.65 * (0.85 * ls + 0.15 * (mu0 < 0.0 ? 0.0 mu0)))
           ; ..a sea's shore wanders: its radius by the bearing from its middle
           (soft m) (: dx (nx - m 0) dy (ny - m 1) an (atan2 dy dx) k (m 0 * 7.0 + m 1 * 11.0)
                       rr (m 2 * (1.0 + 0.13 * sin (2.0 * an + k) + 0.06 * sin (5.0 * an + 2.0 * k)))
                       (sat ((rr - sqrt (dx * dx + dy * dy)) / (0.5 * m 2))))
           mare (foldl (\ b m (b < soft m ? (soft m) b)) 0.0 seas)
           ; ..the highlands' mottle: waves at slants and lengths that never line up
           mott (0.022 * sin (19.0 * nx + 11.0 * ny + 1.3) + 0.018 * sin (-23.0 * nx + 29.0 * ny + 0.4)
                 + 0.014 * sin (43.0 * nx - 31.0 * ny + 2.1) + 0.01 * sin (61.0 * nx + 67.0 * ny))
           (bright c) (: dx (nx - c 0) dy (ny - c 1) r (sqrt (dx * dx + dy * dy))
                         (c 3 * sat (1.0 - r / c 2) + (c 3 = 0.5 ? (0.09 * sat (1.0 - r / 0.7) * (sin (9.0 * atan2 dy dx) @ v (v * v * v * v))) 0.0)))
           alb ((1.0 - 0.42 * mare + mott) * (1.0 + foldl (\ b c (b + bright c)) 0.0 craters))
           tint [(0.95 - 0.12 * mare) (0.93 - 0.1 * mare) (0.88 - 0.04 * mare)]
           earth (0.05 * (1.0 + cos a) / 2.0)
           (ch k) (: v (alb * (tint k * lit + earth * [0.8 0.86 1.0] k)) u (1.0 - exp (0.0 - 1.9 * v))
                     (int (255.0 * sat u + 0.5)))
           (ch 0 * 65536 + ch 1 * 256 + ch 2))))
 ; ..and n by n of it, for pom-cells
 (pom-natural p n) (map (i \ map (j \ pom-glow p ((j + 0.5) * 2 / n - 1) ((i + 0.5) * 2 / n - 1)) ^n) ^n)
 (pom-now _) (: s (clock 0 // 1000) gt (civil (s // 86400))
               (pom-phase (s % 86400 // 3600) <>gt <>>gt <gt))

 ; a grid of rgb or (), two rows to a cell: ▀ in the top's ink on the bottom's ground, ▄ or
 ; ▀ alone for one, a space for none. truecolor when tc, else xterm's nearest of 256
 (pom-tc _) (elem (getenv "COLORTERM") ["truecolor" "24bit"])
 (rgb x) [(x // 65536) (x // 256 % 256) (x % 256)]
 ; an xterm pen of the cube or the grey ramp as rgb, pom-xterm's inverse there
 (xrgb k) (? (232 <= k) ((8 + 10 * (k - 232)) * 65793)
             (: lv [0 95 135 175 215 255] c (k - 16)
                (lv (c // 36) * 65536 + lv (c // 6 % 6) * 256 + lv (c % 6))))
 (pom-xterm x)
  (: c (rgb x) lv [0 95 135 175 215 255]
     q (map (v \ v < 48 ? 0 (v < 115 ? 1 ((v - 35) // 40))) c)
     y (: m (net c // 3) (238 < m ? 23 (max 0 ((m - 3) // 10))))
     (d2 p) (net (map (i \ 2 (c i - p i)) ^3))
     (d2 (map (_ \ 8 + 10 * y) ^3) < d2 (map lv q) ? (232 + y) (16 + 36 * q 0 + 6 * q 1 + q 2)))
 ; the sgr for x as ink (g "38") or ground ("48")
 (pom-tint x g tc) (: c (rgb x) (tc ? (g + ";2;" + show (c 0) + ";" + show (c 1) + ";" + show (c 2))
                                  (g + ";5;" + show (pom-xterm x))))
 (pom-cells g tc)
  (: (cell t b) (? (!(charm? t) && !(charm? b)) " "
                   !(charm? b) (sgr (pom-tint t "38" tc) "▀")
                   !(charm? t) (sgr (pom-tint b "38" tc) "▄")
                   (sgr (pom-tint t "38" tc + ";" + pom-tint b "48" tc) "▀"))
     (map (r \ foldl (\ s x (s + cell (g (2 * r) x) (g (2 * r + 1) x))) "" ^#<g) ^(#g // 2)))

 ; --- the runner ------------------------------------------------------------------
 pom-usage "usage: love pom [-d] [-e] [[[[[[cc]yy]mm]dd]HH]] | -p [N] | -s [N] | -n [N]"
 (digits? s) (#s ? (all digit? (map s ^#s)) 0)
 (env k) (getenv k @ v (string? v ? v ""))
 ; a leading run of digits, perl's reading of a number, and d for none or zero
 (envnum k d) (: v (env k)
                 (go i) (i < #v && digit? (v i) ? (go (i + 1)) i)
                 n (unum (snip v 0 (go 0)))
                 (n ? n d))
 (fail s) (say err ("pom: " + s + "\n"), flush err, 1)
 ; getopts 'de': [d e operands], or () for a letter it does not know
 (flags as d e)
  (: a <as
     (go i d e) (? (#a <= i) (flags >as d e)
                   (a i = 100) (go (i + 1) 1 e)
                   (a i = 101) (go (i + 1) d 1)
                   (say err ("Unknown option: " + string (a i) + "\n"), ()))
     (? !(two? as) [d e ()]
        (a = "--") [d e >as]
        (a = "-" || !(a 0 = 45)) [d e as]
        (go 1 d e)))
 ; the operand in pairs from the right: HH, then dd, mm, yy, cc
 (pairs op) (: (go i) (i < #op ? (snip op i (i + 2) . go (i + 2))) (rev (go 0)))
 ; -p [N]: the moon now, N pixels square, 8 unless said and rounded up to even; -s the
 ; saver's moon the same way, 24 unless said
 (pom-show draw d as)
  (? (two? as && (two? >as || !(digits? <as)))
     (say err (pom-usage + "\n"), flush err, 1)
     (: n (two? as ? (max 2 (unum <as)) d)
        _ (each (pom-cells (draw (pom-now 0) (2 * ((n + 1) // 2))) (pom-tc 0)) (l \ puts (l + "\n")))
        (flush out, 0)))
 (pom-main as) (? (two? as && <as = "-p") (pom-show pom-pixels 8 >as)
                  (two? as && <as = "-s") (pom-show pom-moon 24 >as)
                  (two? as && <as = "-n") (pom-show pom-natural 24 >as)
                  (pom-date as))
 (pom-date as)
  (: fl (flags as 0 0)
     rest (two? fl ? <>>fl)
     op (two? rest ? <rest "")
     (!(two? fl) || two? rest && (two? >rest || !#op || #op & 1 || 10 < #op) ?
        (say err (pom-usage + "\n"), flush err, 1)
        (: dbg <fl enh <>fl
           ps (pairs op)
           (at k d) (k < #ps ? (ps k) d)
           s (clock 0 // 1000)
           gt (civil (s // 86400)) gy <gt gm <>gt gd <>>gt
           hs (at 0 (show (s % 86400 // 3600)))
           ds (at 1 ()) ms (at 2 ()) ys (at 3 ())
           yd (ys ? (at 4 (snip (show gy) 0 2) + ys) (show gy))
           hh (unum hs)
           dd (ds ? (unum ds) gd)
           mo (ms ? (unum ms) gm)
           y (unum yd)
           w (envnum "COLS" (envnum "COLUMNS" 80) - 2)
           h (envnum "LINES" (envnum "ROWS" 25) - 3)
           tm (env "TERM" + " " + env "TERMCAP")
           vt (any (has? tm) ["vt100" "xterm" "ansi" "VT100" "XTERM" "ANSI"])
           (one d k hs)
            (pom-phase k mo d y @ p
               (enh ? (pom-art p w h (show mo + "/" + show d + "/" + yd + ":" + hs))
                  ("The Moon is " + pom-name p + " (" + show (pom-percent p) + "% of Full)\n")))
           (? !(all digits? ps) (fail ("bad number: '" + op + "'"))
              (23 < hh) (fail ("bad hour: '" + hs + "'"))
              (dd = 0 || 31 < dd) (fail ("bad day: '" + show dd + "'"))
              (mo = 0 || 12 < mo) (fail ("bad month: '" + show mo + "'"))
              (w < 0) (fail ("bad terminal width: '" + show w + "'"))
              (w = 0) (fail "terminal width 0")
              (h < 0) (fail ("bad terminal height: '" + show h + "'"))
              (h = 0) (fail "terminal height 0")
              !dbg (puts (one dd hh hs), flush out, 0)
              (: _ (puts ("entered    = yy(" + yd + ")  mm(" + show mo + ")  dd(" + show dd + ")  hh(" + hs + ")\n"
                          + "julian day = " + show (pom-julian mo dd y) + "\n"
                          + "moon phase = " + show (pom-phase hh mo dd y) + "\n"
                          + (enh && vt ? "\e[2J" "")))
                 home (enh ? (vt ? "\e[0;0H" (rep "-" 78 + "\n")) "")
                 (each (map (+ 1) ^31) (d \ each ^24 (k \ puts (home + one d k (show k)))),
                  flush out, 0))))))
 _ (pins (cite 'verbs 'tab) 'pom (udoor 'pom pom-main pom-usage 1 1)))
) ; module pom
