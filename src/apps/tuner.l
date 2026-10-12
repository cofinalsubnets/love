; tuner -- an instrument tuner on the horn's capture door. a vertical scale in eighth tones
; (25 cents a row, four rows a semitone) rising upward and scrolling to hold the pitch at its
; middle; each semitone row names its note and octave (A4), and every label, tick and the
; pitch's own marker wears its octave's hue, red at 0 through violet at 8. a needle below
; spans fifty cents either side of the nearest note.
;   tuner              listen on the first capture node, or HORN_IN's
;   tuner -a HZ        A4 at HZ (440 unless said)
;   tuner -d DEV       listen on DEV, a /dev/snd/pcmC*D*c, /dev/dsp or /dev/sound
;   tuner --demo       no mic: a synthesized glide through four octaves, through the same ear
; keys: a and A move A4 down and up a hertz, q quits.
(module (tuner tuner-main tuner-new tuner-yin tuner-hear tuner-cents tuner-note tuner-frame
               tuner-sine tuner-plain)
(:
   names ["C" "C♯" "D" "D♯" "E" "F" "F♯" "G" "G♯" "A" "A♯" "B"]
   hues [160 202 214 148 41 45 33 99 171]          ; octaves 0..8, red through violet
   pi 3.141592653589793
   peepv (cite 'guts 'peepv)
   rate 48000
   win 2048                                         ; the window yin compares, frames
   lo 24 hi 1200                                    ; its lags: 2 kHz down to 40 Hz
   linger 2500                                      ; ms a reading stands once the sound stops
   tuner-usage "usage: love tuner [-a HZ] [-d DEV] [--demo]
listen and show the pitch on a scale of eighth tones, A4 at HZ (440); DEV is the capture
device (HORN_IN's word otherwise), and --demo glides a sine instead. a/A move A4, q quits."

   (hue o) (hues (max 0 (min 8 o)))
   (ink o s) (sgr ("38;5;" + show (hue o)) s)
   (bold o s) (sgr ("1;38;5;" + show (hue o)) s)
   (faint o s) (sgr ("2;38;5;" + show (hue o)) s)
   (pad s n) (edfit s (max 0 n) " ")                ; plain text only: an escape has no width
   (fmod a b) (a - b * floor (a / b))
   ; a frame with its escapes gone, as a terminal would show it
   (tuner-plain s)
    (: n #s
       (csi i) (i >= n ? i (64 <= s i <= 126 ? (i + 1) (csi (i + 1))))
       (go i acc) (i >= n ? (string (rev acc))
                     (s i = 27 && i + 1 < n && s (i + 1) = 91 ? (go (csi (i + 2)) acc) (go (i + 1) (s i . acc))))
       (go 0 ()))

   ; --- the ear ---------------------------------------------------------------------
   ; yin over a float tray of win + hi samples: each lag's squared difference over the
   ; window, normalised by the running mean (d'), and the first dip under 0.15 refined by a
   ; parabola through it and its neighbours. -> hz, or () where nothing periodic is there.
   ; each lag is one subtract, square and sum over a tray, so the work is the C's
   (tuner-yin x)
    (: a (snip x 0 win)
       (d t) (snip x t (t + win) @ b (a - b @ e (net (e * e))))
       (walk t run p2 p1)
        (t > hi ? ()
           (d t @ v (run + v @ r (t * v / (r + 1e-9) @ n
              (? (t - 1 > lo && p1 < 0.15 && n > p1)          ; p1 was the dip, at lag t - 1
                 (: den (p2 - 2.0 * p1 + n) s (den = 0 ? 0.0 (0.5 * (p2 - n) / den))
                    (rate / (t - 1 + s)))
                 (walk (t + 1) r p1 n))))))
       (walk 1 0.0 1.0 1.0))
   ; s16 mono bytes as a float tray
   (samples s) (: c (cask #s) _ (pour c 0 s 0 #s)
                  t (peepv c 0 2 2 (#s // 2))
                  ((t - 65536 * (t >= 32768)) * 1.0))
   (rms x) ((net (x * x) / #x) ** 0.5)
   (tuner-sine f) (sin ((iota (win + hi)) * (2.0 * pi * f / rate)) * 8000.0)

   ; pitch as cents over midi 0, A4 = 6900 at ref hz; a row of the scale is k = cents / 25
   (tuner-cents ref f) (6900.0 + 1200.0 * log (f / ref) / log 2.0)
   (tuner-note k) (floor (k / 4) @ s [(names (fmod s 12)) (s // 12 - 1) (k - 4 * s)])   ; name octave sub

   ; c is the live reading, () in a silence; last, hz and at the latest one and when it was
   ; heard; lo and hi the note's raw cents, its range since it began; raw its last six, and
   ; nd the needle, eased toward their mean; ncell the cell the needle was drawn in
   (tuner-new ref src) {'ref ref 'src src 'c () 'last 6900.0 'hz () 'at () 'lo () 'hi ()
                        'raw () 'nd 6900.0 'ncell ()
                        'lvl 0 'floor () 'over 0 'clock (_ \ clock 0)}
   ; a reading stands while it is live and for linger ms after its last window
   (held? t now) (t 'at @ a (charm? a && now - a < linger))
   ; a window heard: its level, a pitch where it stands clear of the room, the reading
   ; smoothed in cents. a jump past a quarter tone, or a pitch after the reading has gone,
   ; is a new note: taken whole, its range begun again. the room's floor follows the
   ; quiet: down at once, up a percent a window, and only while nothing is pitched, so a
   ; held note never raises it
   (tuner-hear t x)
    (: now ((t 'clock) 0) l (rms x) fl (t 'floor)
       f (l > 80.0 && (!fl || l > 3.0 * fl) ? (tuner-yin x) ())
       _ (? f 0 (pin t 'floor (? (!fl || l < fl) l (fl * 1.01))))
       (? f
          (: c (tuner-cents (t 'ref) f) p (held? t now ? (t 'last) ())
             new (!p || abs (c - p) > 50.0)
             s (new ? c (p + 0.4 * (c - p)))
             raw (new ? [c] (take 6 (c . t 'raw)))
             nd (new ? c (t 'nd @ n (n + 0.35 * (+raw / #raw - n))))
             (pins t 'lvl l 'c s 'last s 'at now 'hz ((t 'ref) * 2.0 ** ((s - 6900.0) / 1200.0))
                     'lo (new ? c (min c (t 'lo))) 'hi (new ? c (max c (t 'hi))) 'raw raw 'nd nd))
          (pins t 'lvl l 'c ())))

   ; --- the scale ---------------------------------------------------------------------
   ; one row: the label (4), the tick (6) and the axis (1), then the marker or the ¼. the
   ; axis is solid along the note's range
   (row k mark inr)
    (tuner-note k @ [nm o sub]
     ((sub = 0 ? (bold o (pad (nm + show o) 4)) "    ") + " "
      + (sub @ 0 (ink o "━━━━━━") 2 (ink o "  ╺━━━") (sgr "2" "     ·"))
      + (inr ? (bold o "█") (ink o (sub = 0 ? "┫" "┃")))
      + (? mark mark (sub = 2 ? (sgr "2" " ¼") ""))))
   (signed x) ((x >= 0 ? "+" "−") + show (int (abs x + 0.5)))
   ; the marker on the row the pitch falls on: the note, the cents off it, the hz, the
   ; note's range in cents off the same note; faint once the sound has stopped. a narrow
   ; screen keeps the note and the cents
   (marker c f w lo hi gone)
    (: s (floor (c / 100.0 + 0.5)) off (c - 100.0 * s)
       (tuner-note (4 * s) @ [nm o _]
        ((gone ? faint bold) o
         ("◀━━ " + nm + show o + "  " + signed off + "¢"
          + (w < 48 ? "" ("  " + show (int (f * 10.0 + 0.5) / 10.0) + " Hz"))
          + (w < 60 || hi - lo < 1.0 ? "" ("  " + signed (lo - 100.0 * s) + "…" + signed (hi - 100.0 * s) + "¢"))
          + (abs off < 5.0 ? "  ✓" "")))))
   ; the needle: fifty cents either side of the nearest note, its centre the note itself,
   ; the note's range drawn along it. it rides nd, and leaves its cell only for a target
   ; three quarters of a cell away, so a reading on a cell's edge does not flicker across it
   (needle t c w lo hi gone)
    (: s (floor (c / 100.0 + 0.5))
       n (max 11 (w - 4)) mid (n // 2)
       (pos x) (mid + (x - 100.0 * s) / 50.0 * mid)
       (at x) (max 0 (min (n - 1) (floor (pos x + 0.5))))
       was (t 'ncell)
       i0 (two? was && <was = s && abs (pos c - <>was) < 0.75 ? <>was (at c))
       _ (pin t 'ncell [s i0])
       a (at lo) b (at hi)
       (tuner-note (4 * s) @ [_ o _]
        ("  " + cats (map (i \ (? (i = i0) ((gone ? faint bold) o "●") (a <= i <= b) (ink o "━")
                                  (i = mid) (sgr "2" "┃") (sgr "2" "─"))) ^n))))

   ; the screen w by h, as rows: the title, the scale, the needle, a blank and the keys
   (tuner-frame t w h)
    (: on (held? t ((t 'clock) 0)) gone !(t 'c) c (t 'last) lo (t 'lo) hi (t 'hi)
       body (max 5 (h - 4)) cy (body // 2) k0 (floor (c / 25.0 + 0.5))
       klo (on ? (floor (lo / 25.0 + 0.5)) 1) khi (on ? (floor (hi / 25.0 + 0.5)) 0)
       mk (on ? (marker c (t 'hz) w lo hi gone) ())
       rows (map (y \ (k0 + cy - y) @ k (row k (y = cy ? mk ()) (klo <= k <= khi))) ^body)
       top (sgr "7" (pad ("  love tuner   A4 = " + show (t 'ref) + " Hz   " + t 'src
                          + "   level " + show (int (t 'lvl))) w))
       bot (sgr "2" (pad "  ━ semitone  ╺━ quarter tone  · eighth tone    a/A A4 ∓1 Hz   q quit" w))
       ([top] + rows + [(on ? (needle t (t 'nd) w lo hi gone) (sgr "2" "  (listening)")) "" bot]))
   (paint t w h) (tuner-frame t w h @ rs ("\e[H" + cats (map (r \ r + "\e[K\r\n") (init rs)) + last rs + "\e[K"))

   ; --- the ears that feed it -------------------------------------------------------
   ; the mic: the last win + hi frames kept, a reading every 50 ms of fresh ones
   need (2 * (win + hi))
   (listen t h buf fresh)
    (see h @ c (c = -1 || t 'over ? ()
      (: b (buf + string c + chug h) b2 (#b > need ? (snip b (#b - need) #b) b)
         n2 (fresh + #b - #buf)
         (n2 >= 4800 && #b2 >= need ? (tuner-hear t (samples b2), listen t h b2 0) (listen t h b2 n2)))))
   ; the demo: a sine gliding A1 to A5 and back every 16 s
   (demo t t0)
    (: u (fmod (clock t0 / 1000.0) 16.0) e (u < 8.0 ? u (16.0 - u))
       (tuner-hear t (tuner-sine (55.0 * 2.0 ** (e / 2.0))),
        t 'over ? () (: _ (rest 50) (demo t t0))))
   (step t k) (k @ 113 (pin t 'over 1) 97 (pin t 'ref (t 'ref - 1.0)) 65 (pin t 'ref (t 'ref + 1.0)) 0)

   ; N or N.N, a positive float; () for anything else
   (hz s) ((string? s ? (s @ (a + "." + b) (unum a @ x (unum b @ y (charm? x && charm? y ? (x + y / 10.0 ** #b) ())))
                             (unum s @ x (charm? x ? (x * 1.0) ())))
                        ())
           @ f (f && 0 < f ? f ()))
   (tuner-main as)
    (: (bad s) (say err ("tuner: " + s + "\n" + tuner-usage + "\n"), 2)
       (go as ref dev dm)
        (as @ ("-a" . v . r) (hz v @ x (? x (go r x dev dm) (bad ("not a frequency: " + v))))
              ("-d" . v . r) (go r ref v dm)
              ("--demo" . r) (go r ref dev 1)
              () (run ref dev dm)
              (bad ("what is " + <as + "?")))
       (run ref dev dm)
        (: _ (? dev (setenv "HORN_IN" dev) 0)
           h (dm ? () (horn-in rate 1))
           (? (nom? h)
              (: _ (say err ("tuner: no capture device (" + show h + "); -d or HORN_IN names one\n")) 1)
              (: t (tuner-new ref (dm ? "demo" (getenv "HORN_IN" @ x (string? x && #x ? x "mic"))))
                 _ (twirl (_ \ (dm ? (demo t (clock 0)) (listen t h "" 0))) ())
                 _ (stage-run {'show (w \ ht \ paint t w ht) 'step (k \ step t k) 'over? (_ \ t 'over)
                               'tick (_ \ 1) 'every 50 'modes ['hide]})
                 _ (pin t 'over 1)                ; the ear stops; the port's finalizer shuts the device
                 0)))
       (go as 440.0 () 0))

   _ (pins (cite 'verbs 'tab) 'tuner (udoor 'tuner tuner-main tuner-usage 1 1)))
) ; module tuner
