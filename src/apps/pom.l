; pom -- the phase of the moon, after the bsd game by way of pcal's arithmetic. utc,
; the hour its finest grain, as the original.
;   pom          the moon now, one line
;   pom -e       the date, the phase and the moon drawn to the terminal
;   pom -d       every hour of the month; with -e, redrawn in place
;   pom -p [N]   the moon now, N pixels square in half-blocks
;   pom [[[[[cc]yy]mm]dd]HH]  another hour, date(1)'s order
; usage: love pom [-d] [-e] [[[[[[cc]yy]mm]dd]HH]] | -p [N]
(module (pom pom-main pom-julian pom-phase pom-name pom-percent pom-art
             pom-pixels pom-now pom-cells pom-tint pom-tc pom-xterm)
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
 (pom-now _) (: s (clock 0 // 1000) gt (civil (s // 86400))
               (pom-phase (s % 86400 // 3600) <>gt <>>gt <gt))

 ; a grid of rgb or (), two rows to a cell: ▀ in the top's ink on the bottom's ground, ▄ or
 ; ▀ alone for one, a space for none. truecolor when tc, else xterm's nearest of 256
 (pom-tc _) (elem (getenv "COLORTERM") ["truecolor" "24bit"])
 (rgb x) [(x // 65536) (x // 256 % 256) (x % 256)]
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
  (: (sgr c s) ("\e[" + c + "m" + s + "\e[0m")
     (cell t b) (? (!(charm? t) && !(charm? b)) " "
                   !(charm? b) (sgr (pom-tint t "38" tc) "▀")
                   !(charm? t) (sgr (pom-tint b "38" tc) "▄")
                   (sgr (pom-tint t "38" tc + ";" + pom-tint b "48" tc) "▀"))
     (map (r \ foldl (\ s x (s + cell (g (2 * r) x) (g (2 * r + 1) x))) "" ^#<g) ^(#g // 2)))

 ; --- the runner ------------------------------------------------------------------
 pom-usage "usage: love pom [-d] [-e] [[[[[[cc]yy]mm]dd]HH]] | -p [N]"
 (dig? c) (48 <= c < 58)
 (digits? s) (#s ? (all dig? (map s ^#s)) 0)
 (env k) (getenv k @ v (string? v ? v ""))
 ; a leading run of digits, perl's reading of a number, and d for none or zero
 (envnum k d) (: v (env k)
                 (go i) (i < #v && dig? (v i) ? (go (i + 1)) i)
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
 ; -p [N]: the moon now, N pixels square, 8 unless said and rounded up to even
 (pom-show as)
  (? (two? as && (two? >as || !(digits? <as)))
     (say err (pom-usage + "\n"), flush err, 1)
     (: n (two? as ? (max 2 (unum <as)) 8)
        _ (each (pom-cells (pom-pixels (pom-now 0) (2 * ((n + 1) // 2))) (pom-tc 0)) (l \ puts (l + "\n")))
        (flush out, 0)))
 (pom-main as) (two? as && <as = "-p" ? (pom-show >as) (pom-date as))
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
