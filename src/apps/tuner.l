; tuner -- an instrument tuner on the horn's capture door: a scale in eighth tones (25 cents
; a row) scrolling to hold the pitch at its middle, each octave its hue, red at 0 through
; violet at 8; a needle fifty cents either side of the nearest note; the spectrum C1-B7
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
   (ink o s) (sgr "38;5;\(hue o)" s)
   (bold o s) (sgr "1;38;5;\(hue o)" s)
   (faint o s) (sgr "2;38;5;\(hue o)" s)
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
   ; yin over the last win + hi samples: each lag's squared difference over the window,
   ; normalised by the running mean, the first dip under 0.15 refined by a parabola -> hz, or ().
   ; the differences come from the energies and every lag's correlation, one fft there and back
   (fft x) (cite 'dsp 'fft x)
   (ifft x) (cite 'dsp 'ifft x)
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

   ; the spectrum: a bin a semitone C1-B7, each read off a hann-windowed transform of the last
   ; 34 periods or more, a power of two from 1024 frames to long. -> dBFS per bin
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
        pw (foldl (\ t n (pin t n (fft (snip x (m - n) m * hann n) @ z (2 (re z) + 2 (im z))))) {} ns)
        (map ([n kf k] \ (: p (pw n) i (floor kf) u (kf - i)
                            q (at p i + u * (at p (i + 1) - at p i))
                            (20.0 * log (k * (q ** 0.5) / 32768.0 + 1e-9) / log 10.0)))
             bs)))
   (at v i) (peep v i 0.0)

   ; pitch as cents over midi 0, A4 = 6900 at ref hz; a row of the scale is k = cents / 25
   (tuner-cents ref f) (6900.0 + 1200.0 * log (f / ref) / log 2.0)
   (tuner-note k) (floor (k / 4) @ s [(names (fmod s 12)) (s // 12 - 1) (k - 4 * s)])   ; name octave sub

   ; c the live reading, () in a silence; last/hz/at the latest and when; lo hi the note's
   ; raw cents range; raw its last six; nd the needle eased toward their mean; ncell its cell
   (tuner-new ref src) {'ref ref 'src src 'c () 'last 6900.0 'hz () 'at () 'lo () 'hi ()
                        'raw () 'nd 6900.0 'ncell () 'kern () 'spec () 'sp 1
                        'lvl 0 'floor () 'over 0 'clock (_ \ clock 0)}
   ; a reading stands while it is live and for linger ms after its last window
   (held? t now) (t 'at @ a (charm? a && now - a < linger))
   ; a window heard: a jump past a quarter tone, or a pitch after the reading has gone, is a
   ; new note. the room's floor drops at once and rises a percent a window only while nothing
   ; is pitched, so a held note never raises it
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
   ; one row: label (4), tick (6), axis (1), then the marker or the ¼; the axis solid along
   ; the note's range
   (row k mark inr)
    (tuner-note k @ [nm o sub]
     ((sub = 0 ? (bold o (pad (nm + show o) 4)) "    ") + " "
      + (sub @ 0 (ink o "━━━━━━") 2 (ink o "  ╺━━━") (sgr "2" "     ·"))
      + (inr ? (bold o "█") (ink o (sub = 0 ? "┫" "┃")))
      + (? mark mark (sub = 2 ? (sgr "2" " ¼") ""))))
   (signed x) ((x >= 0 ? "+" "−") + show (int (abs x + 0.5)))
   ; the marker: note, cents off, hz, the note's range; faint once the sound stops. a narrow
   ; screen keeps the note and the cents
   (marker c f w lo hi gone)
    (: s (floor (c / 100.0 + 0.5)) off (c - 100.0 * s)
       (tuner-note (4 * s) @ [nm o _]
        ((gone ? faint bold) o
         ("◀━━ \(nm)\(o)  \(signed off)¢"
          + (w < 48 ? "" ("  " + show (int (f * 10.0 + 0.5) / 10.0) + " Hz"))
          + (w < 60 || hi - lo < 1.0 ? "" ("  " + signed (lo - 100.0 * s) + "…" + signed (hi - 100.0 * s) + "¢"))
          + (abs off < 5.0 ? "  ✓" "")))))
   ; the needle: fifty cents either side of the note, its range along it. it leaves its cell
   ; only for a target three quarters of a cell away, so an edge reading does not flicker
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

   ; the spectrum across n columns, four rows of eighth blocks over -60..0 dBFS and a row of
   ; octave Cs; a column takes the loudest of its bins, the reading's column bold
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
   ; the spectrum on its side, n rows from B7 down to C1, bars bw cells long
   ticks ["" "▏" "▎" "▍" "▌" "▋" "▊" "▉"]
   (column t n bw on c)
    (: sp (t 'spec) pb (on ? (floor (c / 100.0 + 0.5) - 24) -1)
       (b0 i) (i * bins // n) (b1 i) (max (b0 i + 1) ((i + 1) * bins // n))
       (lev i) (foldl max -999.0 (take (b1 i - b0 i) (drop (b0 i) sp)))
       (one i) (: o (b0 i // 12 + 1) cb (12 * ((b1 i - 1) // 12))
                  e (max 0 (min (8 * bw) (int ((lev i + 60.0) / 60.0 * 8.0 * bw + 0.5))))
                  lab (b0 i <= cb && (i = 0 || b1 (i - 1) <= cb) ? (ink (cb // 12 + 1) (pad ("C" + show (cb // 12 + 1)) 3)) "   ")
                  (lab + ((b0 i <= pb && pb < b1 i ? bold ink) o (cats (map (_ \ "█") ^(e // 8)) + ticks (e % 8)))))
       (map (r \ one (n - 1 - r)) ^n))
   ; a row's width as the screen shows it, and the row filled out to n with spaces
   (wide s) (tuner-plain s @ p (net (map (b \ b & 192 != 128) (chars p))))
   (fill s n) (s + pad "" (n - wide s))
   ; the screen w by h as rows: title, scale, needle, blank, spectrum, keys. a tall screen
   ; (rows twice the columns) stands the spectrum beside the scale
   besidew 29                                       ; the scale's columns beside a spectrum
   (tuner-frame t w h)
    (: on (held? t ((t 'clock) 0)) gone !(t 'c) c (t 'last) lo (t 'lo) hi (t 'hi)
       spon (t 'sp && two? (t 'spec))
       tall (spon && 2 * h > w && w >= besidew + 12)
       sp (spon && !tall && h >= 24)
       body (max 5 (h - (sp ? 10 4))) cy (body // 2) k0 (floor (c / 25.0 + 0.5))
       klo (on ? (floor (lo / 25.0 + 0.5)) 1) khi (on ? (floor (hi / 25.0 + 0.5)) 0)
       mk (on ? (marker c (t 'hz) (tall ? 0 w) lo hi gone) ())
       sc (map (y \ (k0 + cy - y) @ k (row k (y = cy ? mk ()) (klo <= k <= khi))) ^body)
       rows (tall ? (map ((r . s) \ fill r besidew + s) (zip sc (column t body (w - besidew - 4) on c))) sc)
       top (sgr "7" (pad (w < 50 ? "  tuner  A4 \(t 'ref)  \(t 'src)  level \(int (t 'lvl))"
                                "  love tuner   A4 = \(t 'ref) Hz   \(t 'src)   level \(int (t 'lvl))") w))
       keys "a/A A4 ∓1 Hz  s spectrum  q quit"
       bot (sgr "2" (pad ((? (w < 64) "  " (w < 84) "  ━ semitone  ╺━ ¼  · ⅛    "
                             "  ━ semitone  ╺━ quarter tone  · eighth tone    ") + keys) w))
       nl (on ? (needle t (t 'nd) w lo hi gone) (sgr "2" "  (listening)"))
       ([top] + rows + [nl ""] + (sp ? (strip t (max 11 (w - 4)) on c + [""]) ()) + [bot]))
   (paint t w h) (tuner-frame t w h @ rs ("\e[H" + catmap (r \ "\(r)\e[K\r\n") (init rs) + last rs + "\e[K"))

   ; --- a window's stage: each frame scribed into a quay screen, its dirty rows dyed onto
   ;     the paper, 8 by 16 a cell ---
   (wets sc) (: (bits d base i acc) (i < 32 ? (bits d base (i + 1) (d >> i & 1 ? ((base + i) . acc) acc)) acc)
                (go k acc) (k < 8 ? (go (k + 1) (bits (wet sc k) (32 * k) 0 acc)) acc)
                (go 0 ()))
   (glass t)
    (window-open 640 480 "tuner" @ wd
     (? !(tablet? wd) (say err "tuner: no window (\(wd))\n", 1)
        (tuner-glass t wd, window-close wd, 0)))
   ; t's frames on wd until a close, esc, q or t's own end; a frame follows every turn's events
   (tuner-glass t wd)
    (: gx {}
       (fit w h) (: r (max 8 (h // 16)) c (max 20 (w // 8)) (pins gx () (screen (cask (screen () r c)) r c) 'all 1))
       _ (window-typing wd 0)                     ; a phone's keyboard down: nothing here types
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
   ; the mic: the last long frames kept, a reading every 100 ms once win + hi are in
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
    (: (bad s) (say err "tuner: \(s)\n\(tuner-usage)\n", 2)
       (go as ref dev dm wn)
        (as @ ("-a" . v . r) (hz v @ x (? x (go r x dev dm wn) (bad "not a frequency: \(v)")))
              ("-d" . v . r) (go r ref v dm wn)
              ("--demo" . r) (go r ref dev 1 wn)
              ("--window" . r) (go r ref dev dm 1)
              () (run ref dev dm wn)
              (bad ("what is \(<as)?")))
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
                 _ (pin t 'over 1)                ; the ear stops
                 _ (dm ? 0 (close h))             ; and the device: run in-process the port
                 0)))                             ; outlives tuner until a collection
       (go as 440.0 () 0 0))

   _ (pins (cite 'verbs 'tab) 'tuner (udoor 'tuner tuner-main tuner-usage 1 1)))
) ; module tuner
