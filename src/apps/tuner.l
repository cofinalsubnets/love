; tuner -- an instrument tuner on the horn's capture door. a vertical scale in eighth tones
; (25 cents a row, four rows a semitone) rising upward and scrolling to hold the pitch at its
; middle; each semitone row names its note and octave (A4), and every label, tick and the
; pitch's own marker wears its octave's hue, red at 0 through violet at 8. a needle below
; spans fifty cents either side of the nearest note.
;   tuner              listen on the first capture node, or HORN_IN's
;   tuner -a HZ        A4 at HZ (440 unless said)
;   tuner -d DEV       listen on DEV, a /dev/snd/pcmC*D*c, /dev/dsp or /dev/sound
;   tuner --demo       no mic: a synthesized glide through four octaves, through the same ear
;   tuner --window     in a window of its own (src/apps/window.l): X, inle's screen, a phone
; under the needle, when there is room, the spectrum from C1 to B7 in semitones.
; keys: a and A move A4 down and up a hertz, s shows or hides the spectrum, q quits. in a
; window a tap is a key too: a on the left third, A on the right, s between.
(module (tuner tuner-main tuner-new tuner-yin tuner-hear tuner-cents tuner-note tuner-frame
               tuner-sine tuner-tone tuner-plain tuner-spectrum tuner-glass)
(borrow 'window)
(:
   names ["C" "C♯" "D" "D♯" "E" "F" "F♯" "G" "G♯" "A" "A♯" "B"]
   hues [160 202 214 148 41 45 33 99 171]          ; octaves 0..8, red through violet
   pi 3.141592653589793
   peepv (cite 'guts 'peepv)
   rate 48000
   win 2048                                         ; the window yin compares, frames
   lo 24 hi 1200                                    ; its lags: 2 kHz down to 40 Hz
   linger 2500                                      ; ms a reading stands once the sound stops
   tuner-usage "usage: love tuner [-a HZ] [-d DEV] [--demo] [--window]
listen and show the pitch on a scale of eighth tones, A4 at HZ (440); DEV is the capture
device (HORN_IN's word otherwise), and --demo glides a sine instead; --window draws in a
window, where a tap on its left, middle or right third is a, s or A. a/A move A4, s the
spectrum, q quits."

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
   ; yin over the last win + hi samples of a float tray: each lag's squared difference over
   ; the window, normalised by the running mean (d'), and the first dip under 0.15 refined by
   ; a parabola through it and its neighbours. -> hz, or () where nothing periodic is there.
   ; the difference is the window's energy, the lagged window's and twice their correlation,
   ; and the correlations of every lag are one transform there and back
   (fft x) ((cite 'dsp 'fft) x)
   (ifft x) ((cite 'dsp 'ifft) x)
   (tuner-yin x)
    (: y (recent x)
       sq (y * y) c (re (ifft (conj (fft (y * (iota #y < win))) * fft y)))
       r0 (net (snip sq 0 win))
       (walk t e run p2 p1)
        (t > hi ? ()
           (e - at sq (t - 1) + at sq (t + win - 1) @ e2 (r0 + e2 - 2.0 * at c t @ v (run + v @ r (t * v / (r + 1e-9) @ n
              (? (t - 1 > lo && p1 < 0.15 && n > p1)          ; p1 was the dip, at lag t - 1
                 (: den (p2 - 2.0 * p1 + n) s (den = 0 ? 0.0 (0.5 * (p2 - n) / den))
                    (rate / (t - 1 + s)))
                 (walk (t + 1) e2 r p1 n)))))))
       (walk 1 r0 0.0 1.0 1.0))
   ; s16 mono bytes as a float tray
   (samples s) (: c (cask #s) _ (pour c 0 s 0 #s)
                  t (peepv c 0 2 2 (#s // 2))
                  ((t - 65536 * (t >= 32768)) * 1.0))
   (rms x) ((net (x * x) / #x) ** 0.5)
   (recent x) (#x > win + hi ? (snip x (#x - win - hi) #x) x)    ; what yin and the level hear
   (tuner-tone f n) (sin ((iota n) * (2.0 * pi * f / rate)) * 8000.0)
   (tuner-sine f) (tuner-tone f (win + hi))

   ; the spectrum: one bin a semitone from C1 to B7, each read at its pitch off a hann-windowed
   ; transform of the last 34 periods or more, a power of two from 1024 frames to long or the
   ; most the buffer holds. -> dBFS per bin
   bins 84
   long 32768                                       ; the spectrum's longest look, frames
   (up2 n) (n <= 1 ? 1 (2 * up2 ((n + 1) // 2)))
   (down2 n) (n < 2 ? 1 (2 * down2 (n // 2)))
   hanns {}
   (hann n) (hanns n @ w (tray? w ? w (iota n * (2.0 * pi / (n - 1)) @ i (pin hanns n (0.5 - 0.5 * cos i), hanns n))))
   ; per bin its transform's length, its pitch in that transform's bins, and the scale from
   ; a peak's root power to the sine's amplitude
   (plan ref m)
    (: cap (min long (down2 m))
       bs (map (b \ (: f (ref * 2.0 ** ((b - 45) / 12.0)) n (min cap (max 1024 (up2 (int (34.0 * rate / f)))))
                       [n (f * n / rate) (2.0 / net (hann n))]))
               ^bins)
       [(sort (keys (foldl (\ t b (pin t <b 1)) {} bs))) bs])
   (tuner-spectrum pl x)
    (pl @ [ns bs]
     (: m #x
        pw (foldl (\ t n (pin t n (fft (snip x (m - n) m * hann n) @ z (re z * re z + im z * im z)))) {} ns)
        (map ([n kf k] \ (: p (pw n) i (floor kf) u (kf - i)
                            q (at p i + u * (at p (i + 1) - at p i))
                            (20.0 * log (k * (q ** 0.5) / 32768.0 + 1e-9) / log 10.0)))
             bs)))
   (at v i) (peep v i 0.0)

   ; pitch as cents over midi 0, A4 = 6900 at ref hz; a row of the scale is k = cents / 25
   (tuner-cents ref f) (6900.0 + 1200.0 * log (f / ref) / log 2.0)
   (tuner-note k) (floor (k / 4) @ s [(names (fmod s 12)) (s // 12 - 1) (k - 4 * s)])   ; name octave sub

   ; c is the live reading, () in a silence; last, hz and at the latest one and when it was
   ; heard; lo and hi the note's raw cents, its range since it began; raw its last six, and
   ; nd the needle, eased toward their mean; ncell the cell the needle was drawn in
   (tuner-new ref src) {'ref ref 'src src 'c () 'last 6900.0 'hz () 'at () 'lo () 'hi ()
                        'raw () 'nd 6900.0 'ncell () 'kern () 'spec () 'sp 1
                        'lvl 0 'floor () 'over 0 'clock (_ \ clock 0)}
   ; a reading stands while it is live and for linger ms after its last window
   (held? t now) (t 'at @ a (charm? a && now - a < linger))
   ; a window heard: its level, a pitch where it stands clear of the room, the reading
   ; smoothed in cents. a jump past a quarter tone, or a pitch after the reading has gone,
   ; is a new note: taken whole, its range begun again. the room's floor follows the
   ; quiet: down at once, up a percent a window, and only while nothing is pitched, so a
   ; held note never raises it
   (tuner-hear t x)
    (: now ((t 'clock) 0) l (rms (recent x)) fl (t 'floor)
       kk (t 'kern) key [(t 'ref) (min long (down2 #x))]
       pl (two? kk && <kk = key ? >kk (plan (t 'ref) #x))
       sp (tuner-spectrum pl x) old (t 'spec)
       _ (pins t 'kern (key . pl) 'spec (two? old ? (map (p \ max <p (>p - 3.0)) (zip sp old)) sp))
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

   ; the spectrum across n columns, four rows of eighth blocks over -60..0 dBFS and a row
   ; naming each octave's C; a column takes the loudest of its bins and its octave's hue,
   ; and the reading's own column is bold
   blocks [" " "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"]
   (strip t n on c)
    (: sp (t 'spec) pb (on ? (floor (c / 100.0 + 0.5) - 24) -1)
       (b0 i) (i * bins // n) (b1 i) (max (b0 i + 1) ((i + 1) * bins // n))
       (lev i) (foldl max -999.0 (take (b1 i - b0 i) (drop (b0 i) sp)))
       cols (map (i \ [(b0 i // 12 + 1) (b0 i <= pb && pb < b1 i)
                       (max 0 (min 32 (int ((lev i + 60.0) / 60.0 * 32.0 + 0.5))))]) ^n)
       (bar r) ("  " + cats (map ([o me e] \ (max 0 (min 8 (e - 8 * (3 - r))) @ k
                                   (k = 0 ? " " ((me ? bold ink) o (blocks k))))) cols))
       (lab i acc) (i >= n ? (cats (rev acc))
                      ((b1 i - 1) // 12 @ o (b0 i <= 12 * o && i + 2 <= n
                         ? (lab (i + 2) (ink (o + 1) ("C" + show (o + 1)) . acc))
                         (lab (i + 1) (" " . acc)))))
       (map bar ^4 + [("  " + lab 0 ())]))
   ; the screen w by h, as rows: the title, the scale, the needle, a blank, the spectrum
   ; with a blank under it when there is room and it is on, and the keys
   (tuner-frame t w h)
    (: on (held? t ((t 'clock) 0)) gone !(t 'c) c (t 'last) lo (t 'lo) hi (t 'hi)
       sp (t 'sp && two? (t 'spec) && h >= 24)
       body (max 5 (h - (sp ? 10 4))) cy (body // 2) k0 (floor (c / 25.0 + 0.5))
       klo (on ? (floor (lo / 25.0 + 0.5)) 1) khi (on ? (floor (hi / 25.0 + 0.5)) 0)
       mk (on ? (marker c (t 'hz) w lo hi gone) ())
       rows (map (y \ (k0 + cy - y) @ k (row k (y = cy ? mk ()) (klo <= k <= khi))) ^body)
       top (sgr "7" (pad ("  love tuner   A4 = " + show (t 'ref) + " Hz   " + t 'src
                          + "   level " + show (int (t 'lvl))) w))
       bot (sgr "2" (pad "  ━ semitone  ╺━ quarter tone  · eighth tone    a/A A4 ∓1 Hz  s spectrum  q quit" w))
       nl (on ? (needle t (t 'nd) w lo hi gone) (sgr "2" "  (listening)"))
       ([top] + rows + [nl ""] + (sp ? (strip t (max 11 (w - 4)) on c + [""]) ()) + [bot]))
   (paint t w h) (tuner-frame t w h @ rs ("\e[H" + cats (map (r \ r + "\e[K\r\n") (init rs)) + last rs + "\e[K"))

   ; --- a window's stage: each frame scribed into a quay screen, the glass, and the rows it
   ;     names dirty dyed onto the paper, 8 by 16 a cell; every row onto a fresh paper ---
   (wets sc) (: (bits d base i acc) (i < 32 ? (bits d base (i + 1) (d >> i & 1 ? ((base + i) . acc) acc)) acc)
                (go k acc) (k < 8 ? (go (k + 1) (bits (wet sc k) (32 * k) 0 acc)) acc)
                (go 0 ()))
   (glass t)
    (window-open 640 480 "tuner" @ wd
     (? !(tablet? wd) (say err ("tuner: no window (" + show wd + ")\n"), 1)
        (tuner-glass t wd, window-close wd, 0)))
   ; t's frames on wd until a close, esc, q or t's own end; a frame follows every turn's events
   (tuner-glass t wd)
    (: gx {}
       (fit w h) (: r (max 8 (h // 16)) c (max 20 (w // 8)) (pins gx () (screen (cask (screen () r c)) r c) 'all 1))
       _ (fit <(window-size wd) (window-size wd 1))
       (tap x) (<(window-size wd) @ w (step t (? (x < w // 3) 97 (x >= 2 * w // 3) 65 115)))
       (event e) (e @ ['text s] (each ^#s (i \ step t (s i))) ['press _ x _] (tap x) ['size w h] (fit w h)
                        ['down 1] (pin t 'over 1) ['close] (pin t 'over 1) 0)
       (show _) (: sc (gx ()) r (gaze sc 1) c (gaze sc 2) p (window-paper wd) W <(window-size wd)
                   _ (scribe sc (paint t c r))
                   ys (wets sc @ d (gx 'all ? (pin gx 'all 0, ^r) d))
                   (two? ys ? (each ys (y \ dye sc p W y -1 ()), window-show wd (16 * foldl min <ys ys) (16 * foldl max <ys ys + 16)) 0))
       (go _) (each (window-events wd) event, show 0, t 'over ? 0 (rest 50, go 0))
       (go 0))

   ; --- the ears that feed it -------------------------------------------------------
   ; the mic: the last long frames kept, a reading every 100 ms of fresh ones once yin's
   ; win + hi are in
   need (2 * (win + hi)) keep (2 * long)
   (listen t h buf fresh)
    (see h @ c (c = -1 || t 'over ? ()
      (: b (buf + string c + chug h) b2 (#b > keep ? (snip b (#b - keep) #b) b)
         n2 (fresh + #b - #buf)
         (n2 >= 4800 && #b2 >= need ? (tuner-hear t (samples b2), listen t h b2 0) (listen t h b2 n2)))))
   ; the demo: a sine gliding A1 to A5 and back every 16 s
   (demo t t0)
    (: u (fmod (clock t0 / 1000.0) 16.0) e (u < 8.0 ? u (16.0 - u))
       (tuner-hear t (tuner-tone (55.0 * 2.0 ** (e / 2.0)) long),
        t 'over ? () (: _ (rest 50) (demo t t0))))
   (step t k) (k @ 113 (pin t 'over 1) 115 (pin t 'sp (1 - t 'sp)) 97 (pin t 'ref (t 'ref - 1.0)) 65 (pin t 'ref (t 'ref + 1.0)) 0)

   ; N or N.N, a positive float; () for anything else
   (hz s) ((string? s ? (s @ (a + "." + b) (unum a @ x (unum b @ y (charm? x && charm? y ? (x + y / 10.0 ** #b) ())))
                             (unum s @ x (charm? x ? (x * 1.0) ())))
                        ())
           @ f (f && 0 < f ? f ()))
   (tuner-main as)
    (: (bad s) (say err ("tuner: " + s + "\n" + tuner-usage + "\n"), 2)
       (go as ref dev dm wn)
        (as @ ("-a" . v . r) (hz v @ x (? x (go r x dev dm wn) (bad ("not a frequency: " + v))))
              ("-d" . v . r) (go r ref v dm wn)
              ("--demo" . r) (go r ref dev 1 wn)
              ("--window" . r) (go r ref dev dm 1)
              () (run ref dev dm wn)
              (bad ("what is " + <as + "?")))
       (run ref dev dm wn)
        (: _ (? dev (setenv "HORN_IN" dev) 0)
           h (dm ? () (horn-in rate 1))
           (? (nom? h)
              (: _ (say err ("tuner: no capture device (" + show h + "); -d or HORN_IN names one\n")) 1)
              (: t (tuner-new ref (dm ? "demo" (getenv "HORN_IN" @ x (string? x && #x ? x "mic"))))
                 _ (twirl (_ \ (dm ? (demo t (clock 0)) (listen t h "" 0))) ())
                 _ (wn ? (glass t)
                       (stage-run {'show (w \ ht \ paint t w ht) 'step (k \ step t k) 'over? (_ \ t 'over)
                                   'tick (_ \ 1) 'every 50 'modes ['hide]}))
                 _ (pin t 'over 1)                ; the ear stops; the port's finalizer shuts the device
                 0)))
       (go as 440.0 () 0 0))

   _ (pins (cite 'verbs 'tab) 'tuner (udoor 'tuner tuner-main tuner-usage 1 1)))
) ; module tuner
