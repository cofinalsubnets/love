; view -- what a first-person level in half blocks rides: the screen as a camera on the
; state, the rays its columns cast, the pens said a change at a time, the tty loop that
; runs a level, and the small arithmetic the scenes share. a scene that colours every
; pixel says its colours as pens here too: 24-bit, or the 256 palette dithered.
(module (view esc pi clamp flo wrap over throw sgr view! view-hz view-size view-rays
         view-frame view-walk view-run view-bayer view-deep-pens view-cube-pens view-deep-frame
         view-deep? view-words view-flag view-window view-arg view-scale view-main view-song view-stage view-set1
         view-binds view-bind view-walking view-repeat view-listed view-help view-help-say view-help-bands
         view-pen view-band
         view-rescale view-scaled view-gauge view-gauged view-loading view-busy view-spin view-tick view-corner? view-middle? view-tap)
(borrow '(rove cli))
(borrow 'horn)                          ; the pacer, the horn's lead, the keys drained
(borrow '(slip console))                ; the console's pane beside the scene's
(borrow 'window)                        ; a level in a window of its own, its keys held
(borrow 'lore)                          ; frame-paint, in C
(borrow 'posix)    ; close, for the horn
(:
 esc (string 27)
 pi 3.141592653589793
 (clamp v lo hi) (v < lo ? lo (hi < v ? hi v))
 (flo v) (int (v + 1000.0) - 1000)
 (wrap a) (a < -pi ? (wrap (a + tau)) (pi < a ? (wrap (a - tau)) a))
 (over c m v) (c + m * (v - c))                          ; v where the mask holds, c elsewhere
 ; the hash: two rounds of multiply, shift and mask kept under 32 bits, so a tray's
 ; machine words and a number throw alike
 m32 4294967295
 (mash a) (: h ((a & m32) * 1103515245 & m32) h2 ((h ^ h >> 15) * 1664525 & m32) (h2 ^ h2 >> 13))
 (throw x y s k) (mash (y * 374761393 + x * 668265263 + s * 2654435761 + 1) % k)
 ; a pen on a ground as an sgr, kept once said
 sgrs {}
 (sgr f b) (: k (f * 256 + b) s (sgrs k)
              (string? s ? s (esc + "[38;5;" + show f + ";48;5;" + show b + "m" @ s2 (pin sgrs k s2, s2))))
 ; the screen rides the state: 'w and 'h its pixels, 'cx the middle column, 'foc the
 ; focal length, half the width for a view ninety degrees wide, 'hz the horizon's row
 (view! st w h hz) (pins st 'w w 'h h 'cx (w / 2.0) 'foc (w / 2.0) 'hz hz)
 ; the horizon at a row, kept out of the screen's top and bottom nth
 (view-hz st hz n) (: h (st 'h) (pin st 'hz (clamp hz (h // n) ((n - 1) * h // n))))
 ; resized to w cells across and r rows, two pixels a row, the horizon kept where it
 ; stood in proportion
 (view-size st w r n) (: h (2 * r) hz (st 'hz * h // st 'h) (view-hz (view! st w h hz) hz n))
 ; each column's ray through its middle, facing 'th: [x z] trays of its direction
 (view-rays st) (: th (st 'th) sn (sin th) cs (cos th) u ((iota (st 'w) + 0.5 - st 'cx) / st 'foc)
                   [(sn + u * cs) (cs - u * sn)])
 ; a frame: two pixel rows a cell, the upper half block with the top pixel in the pen and
 ; the bottom in the ground, one sgr per change, the rows joined by \r\n with no newline
 ; after the last, so a screen of just enough rows never scrolls. (src y) is pixel row
 ; y's pens, a tray or a cask; bands holds a cell row's words, [x0 text fg bg], laid over
 ; the cells they cover
 (view-frame w h src bands) (: j (jug 0)
   (row x f b ts bs bd) (x < w ?
     (: tx (two? bd && bd 0 <= x < bd 0 + #(bd 1))
        f2 (tx ? (bd 2) (peep ts x 0)) b2 (tx ? (bd 3) (peep bs x 0))
        (f2 != f || b2 != b ? (say j (sgr f2 b2)),
         say j (tx ? (string (bd 1 (x - bd 0))) "▀"),
         row (x + 1) f2 b2 ts bs bd)))
   (rows y) (y < h // 2 ? (row 0 -1 -1 (src (2 * y)) (src (2 * y + 1)) (bands y),
                           say j (esc + "[0m"), y + 1 < h // 2 ? (say j "\r\n"), rows (y + 1)))
   (rows 0, slurp j))
 ; --- colours to pens: c a triple of trays, each part 0 to 1 ---
 (sat1 v) (min 1.0 (max 0.0 v))
 ; each pixel's place in a 4 by 4 bayer square, a w by h screen's worth, as the dither's
 ; offset between two steps
 bayer (star-tray [16] [0 8 2 10 12 4 14 6 3 11 1 9 15 7 13 5])
 (view-bayer w h) (: i (iota (w * h)) (bayer (i // w % 4 * 4 + i % w % 4) / 16.0 + 1.0 / 32.0))
 ; 24-bit, six bits a channel packed
 (view-deep-pens c) (: (q v) (int (sat1 v * 63.0 + 0.5)) (q (c 0) * 4096 + q (c 1) * 64 + q (c 2)))
 ; ..or the 256 palette's cube or grey ramp, dithered between the two steps round each part
 ; by bay. the upper step's share is the one that mixes to the part's light (its square,
 ; near enough to the eye's), not its code: the cube's first step is 0 to 95, and a code
 ; half way there dithered half and half reads far too bright
 ; ..the steps' lights squared, gathered by step: the cube's by its code, the grey ramp's
 ; lower and upper by its code + 1
 (cube-lvl k) (over (0.0 * k) (0 < k) ((55.0 + 40.0 * k) / 255.0))
 cube-sq (cube-lvl (iota 6) @ a (2 a))
 grey-lo (iota 24 - 1 @ gl (over ((8.0 + 10.0 * gl) / 255.0) (gl < 0) 0.0) @ a (2 a))
 grey-hi (iota 24 - 1 @ gl ((18.0 + 10.0 * gl) / 255.0) @ b (2 b))
 (dith a2 b2 v bay) (over 0 (bay < (2 v - a2) / (b2 - a2)) 1)
 (view-cube-pens c bay) (: (ix v) (: u (sat1 v)
     lo (max 0 (min 4 (floor (over (u * 255.0 / 95.0) (95.0 / 255.0 <= u) (1.0 + (u * 255.0 - 95.0) / 40.0)))))
     (lo + dith (peep cube-sq lo 0.0) (peep cube-sq (lo + 1) 0.0) u bay))
   r (c 0) g (c 1) bl (c 2)
   chroma (max r (max g bl) - min r (min g bl))
   y (sat1 (0.299 * r + 0.587 * g + 0.114 * bl))
   gl (max -1 (min 22 (floor ((y * 255.0 - 8.0) / 10.0))))          ; -1 the black below the ramp
   d (dith (peep grey-lo (gl + 1) 0.0) (peep grey-hi (gl + 1) 0.0) y bay)
   grey (over (232 + gl + d) ((gl + d) < 0) 16)
   cube (16 + 36 * ix r + 6 * ix g + ix bl)
   (over cube (chroma < 0.08) grey))
 ; a frame of 24-bit pens, px a tray a screen wide: view-frame's, each pen's words kept
 ; once said, and only the half that changed said again
 tints {}
 (tint c) (: s (tints c)
             (string? s ? s
                (: (ch k) (show ((c >> k & 63) * 255 // 63))
                   s2 (ch 12 + ";" + ch 6 + ";" + ch 0)
                   n (peep tints -1 0)
                   _ (60000 < n ? (each (keys tints) (k \ pin tints k ())))
                   (pins tints c s2 -1 (n + 1), s2))))
 (deep-sgr f b f2 b2) (? (f2 = f) (esc + "[48;2;" + tint b2 + "m")
                         (b2 = b) (esc + "[38;2;" + tint f2 + "m")
                         (esc + "[38;2;" + tint f2 + ";48;2;" + tint b2 + "m"))
 (view-deep-frame w h px bands) (: j (jug 0)
   (row x f b i bd) (x < w ?
     (: tx (two? bd && bd 0 <= x < bd 0 + #(bd 1))
        f2 (tx ? (bd 2) (peep px (i + x) 0)) b2 (tx ? (bd 3) (peep px (i + w + x) 0))
        (f2 != f || b2 != b ? (say j (deep-sgr f b f2 b2)),
         say j (tx ? (string (bd 1 (x - bd 0))) "▀"),
         row (x + 1) f2 b2 i bd)))
   (rows y) (y < h // 2 ? (row 0 -1 -1 (2 * y * w) (bands y),
                           say j (esc + "[0m"), y + 1 < h // 2 ? (say j "\r\n"), rows (y + 1)))
   (rows 0, slurp j))
 ; --- keys: a binding is a tablet, a key's code -> the action it names, a symbol. a code is
 ;     what a terminal sends, its byte, or an arrow as the cli has it, -1 -2 -8 -9; a window's
 ;     keys come to the same codes. a level binds its own over these ---
 view-binds {104 'turn-left -1 'turn-left 108 'turn-right -2 'turn-right 107 'forward -8 'forward
             106 'back -9 'back 117 'look-up 110 'look-down 63 'help 113 'quit 27 'quit
             43 'finer 61 'finer 45 'coarser 48 'auto 126 'console 96 'console}
 ; ..b with o laid over it, o's own winning; a code o binds to () comes unbound
 (view-bind b o) (: t {} _ (each (keys b) (k \ pin t k (b k))) _ (each (keys o) (k \ pin t k (o k))) t)
 ; ..a picture's pixel scale halved or doubled, 1 to 8, and the screen sized again for it:
 ; fewer pixels drawn for more frames, or the other way
 (view-rescale lv st a) (: s (peep st 'scale 2) (view-scaled lv st (a @ 'finer (max 1 (s // 2)) (min 8 (s * 2)))))
 (view-scaled lv st s) (pin st 'scale s, lv 'size st (st 'w) (st 'h // 2))
 ; ..or moved a step at a time by the frame's time: a gauge over steps whose pixels are pix,
 ; finest first, at step i, a frame's goal in ms with the song's feed counted in it
 (view-gauge pix i goal) {'pix pix 'i i 'goal goal 'p () 'f () 'at () 'low () 'sl () 'bk () 'seen {}}
 ; ..a frame's paint and feed ms, and whether the horn is running low, at clock t: the step
 ; to draw at. coarser half a second after a step on a low horn, a second after it over the
 ; goal, five on one come back to, where the coarser step's frame is guessed under 0.9 of
 ; this one's; back a step a second on where this one's is not under 0.9 of the finer's,
 ; measured; finer three seconds from a step, where its frame is guessed under 0.8 of the
 ; goal, or tried where this one's is under half the goal and the finer's is not measured;
 ; neither back nor finer within three seconds of a low horn. a step's frame is its own, a
 ; slow mean with a spike held to twice it, measured half a second on and kept half a minute,
 ; else a line through this step's and the nearest other measured, a part fixed and a part by
 ; the pixels, else the pixels' share of this one. the feed's share is a slow mean, so a
 ; phrase's spike leans on the horn's lead rather than the picture
 (view-gauged g ms fd low t) (: (avg o x k) (o @ () (1.0 * x) (o + k * (x - o)))
   p (avg (g 'p) ms 0.25) f (avg (g 'f) fd 0.0625) at (g 'at @ () t a a) i (g 'i) pix (g 'pix)
   b (g 'goal - f) held (t - at) lw (low ? t (g 'low)) quiet (lw = () || 3000 <= t - lw)
   sl (g 'sl @ () (min (1.0 * ms) (2.0 * p)) o (o + 0.0625 * (min ms (2.0 * o) - o)))
   sn (g 'seen) _ (500 <= held ? (pin sn i [sl t]))
   (fresh k) (sn k @ [q s] (t - s <= 30000 ? q) ())
   (guess k) (fresh k @ ()
               (: ws (filter (m \ m != i && fresh m != ()) ^#pix)
                  (ws = () ? (sl * pix k / pix i)
                     (: m (foldl (\ n m (abs (m - k) < abs (n - k) ? m n)) <ws >ws)
                        c (max 0.0 ((sl - fresh m) / (pix i - pix m))) a (max 0.0 (sl - c * pix i))
                        (a + c * pix k))))
               q q)
   bk (0 < i && 1000 <= held && quiet && (fresh (i - 1) @ () 0 q (0.9 * q <= sl)))
   j (? (i + 1 < #pix && (low && 500 <= held || b < sl && (g 'bk = i ? 5000 1000) <= held) && guess (i + 1) < 0.9 * sl) (i + 1)
        bk (i - 1)
        (0 < i && 3000 <= held && quiet && (guess (i - 1) < 0.8 * b || fresh (i - 1) = () && sl < 0.5 * b)) (i - 1)
        i)
   (pins g 'p (j = i ? p (guess j)) 'sl (j = i ? sl ()) 'bk (? (j = i) (g 'bk) (bk && j < i) j ()) 'f f 'at (j = i ? at t) 'low lw 'i j, j))
 ; ..the walking ones, which act again while a window's key is held: after a pause, then
 ; at a pace (ms), like a keyboard's own repeat
 view-repeat [250 110]
 ; ..a thumb's pixels before it counts as moved, and how much further its drag looks than a mouse
 view-thumb-still 10 view-thumb-look 2 view-thumb-run 50
 view-walking ['forward 'back 'turn-left 'turn-right 'look-up 'look-down]
 ; a key in a window, by its place -> its code where it types nothing: space, esc, enter,
 ; the arrows; the rest come by what they type
 view-set1 {1 27 28 13 57 32 331 -1 333 -2 328 -8 336 -9
            16 113 17 119 18 101 19 114 20 116 21 121 22 117 23 105 24 111 25 112
            30 97 31 115 32 100 33 102 34 103 35 104 36 106 37 107 38 108
            44 122 45 120 46 99 47 118 48 98 49 110 50 109 53 47
            41 96 2 49 3 50 4 51 5 52 6 53 7 54 8 55 9 56 10 57 11 48}
 ; --- the help: the actions listed, a line each in their order, every key b binds to it and
 ;     its name; one b binds no key to is left out ---
 (view-key-name k) (k @ -1 "←" -2 "→" -8 "↑" -9 "↓" 32 "space" 27 "esc" 13 "enter" 10 "enter" 9 "tab"
                     (32 < k && k < 127 ? (string k) ("#" + show k)))
 ; ..the listed a level that says none has: the walking ones, then its own, then help and quit
 (view-listed own) (view-walking + own + ['help 'quit])
 (view-help b listed) (: cs (sort (filter (k \ b k != ()) (keys b)))
   acts (filter (a \ elem a (map b cs)) listed)
   (names a) (join " " (uniq (map view-key-name (filter (k \ b k = a) cs))))
   wd (foldl max 0 (map (vlen * names) acts))
   (map (a \ pad (names a) wd " " + "  " + show a) acts))
 ; ..laid in a box over the middle of a w by r cell screen: [x0 y0 rows], each row as wide
 ; as the box
 (view-help-box ls w r) (: bw (2 + foldl max 0 (map vlen ls)) rows (map (l \ " " + pad l (bw - 2) " " + " ") ([""] + ls + [""]))
   [(max 0 ((w - bw) // 2)) (max 0 ((r - #rows) // 2)) rows])
 ; ..to a terminal, over the frame and in the same synchronised update, so the two are
 ; shown as one: inside the frame's own, or one of its own round them
 (view-synced f o) (: e (esc + "[?2026l") n #e
   (? (n <= #f && snip f (#f - n) #f = e) (snip f 0 (#f - n) + o + e)
      (esc + "[?2026h" + f + o + e)))
 (view-help-say st ls) (view-box-say st (view-help-box ls (st 'w) (st 'h // 2)))
 (view-box-say st b) (b @ [x0 y0 rows]
   (foldl (+) "" (map (i \ esc + "[" + show (y0 + i + 1) + ";" + show (x0 + 1) + "H"
                          + esc + (st 'deep ? "[38;2;220;214;200;48;2;24;22;20m" "[38;5;253;48;5;235m")
                          + rows i + esc + "[0m")
                      ^#rows)))
 ; ..or as bands, a row's [x0 cells fg bg], its pens 24-bit six bits a channel or the 256
 (view-help-bands st ls) (view-box-bands st (view-help-box ls (st 'w) (st 'h // 2)))
 (view-box-bands st b) (b @ [x0 y0 rows]
   (: dp (st 'deep) fg (dp ? (55 << 12 | 53 << 6 | 50) 253) bg (dp ? (6 << 12 | 5 << 6 | 5) 235)
      (foldl (t \ i \ pin t (y0 + i) [x0 (con-cells (rows i)) fg bg]) {} ^#rows)))
 ; a band's pen [r g b n] as deep or the 256 has it
 (view-pen deep v) (deep ? (: (q x) ((x * 63 + 127) // 255) (q (v 0) * 4096 + q (v 1) * 64 + q (v 2))) (v 3))
 ; ..and a line s laid as the band on row r, light on bg
 (view-band st s r bg) {(r - 1) [0 (con-cells s) (view-pen (st 'deep) [240 240 240 255]) (view-pen (st 'deep) bg)]}
 ; a level lv on a stage already raised, a frame a tick. lv: 'new (w h) its state, 'size
 ; (st w r), 'frame (st), 'key (st action), 'tick (st), 'fps, 'linger once 'done, 'next
 ; [module walk] or (), 'song (hn) a feeder of (st), hn () with no horn, fed every frame;
 ; optional 'words (st) the console's, [[name doc value] ..], 'binds 'listed 'win 'repeat ([pause gap] ms), 'walking the actions that repeat
; and 'held (st) to stop a repeat; 'stick [ahead back left right], those keys for a phone's
; thumbs, and 'tap (st x y) the keys a tap at pixel x y is, view-tap unless said.
 ; help shows in a terminal until the next key, which does nothing else; in a window while
 ; held. in a window the frame paints itself (mesh-show) and a cell is 8 by 16 pixels
 (view-walk lv) (:
   win (lv 'win)
   binds (peep lv 'binds view-binds)
   hl (view-help binds (peep lv 'listed (view-listed ())))
   hs {'on 0 'p ()}
   ; ..the console, on any level; the level's 'words its own, beside st
   con (con-new ()) words (peep lv 'words (_ \ ())) at (c \ view-set1 c)
   ; ..on a phone, the panes side by side
   phone (win && win 'how = 'droid) _ (phone ? (pin con 'split ['beside 60 'scene 'con]) 0)
   (eval l) (con-task (_ \ con-eval words st l) (_ \ con-stop con win at))
   (con? k) (binds k = 'console)
   ; ..the keys held let go as the console takes them
   (let-go _) (con-keyed? con ? (each (keys held) (c \ pin held c ())) ())
   ; ..the mouse, where the level looks by it: a click holds it, its motion from the window's
   ; middle summed for the frame and it put back there, esc lets it go
   look (lv 'look) ms {'on 0 'dx 0 'dy 0}
   ; ..and its buttons, once it is held or where nothing looks by it, to the level's 'mouse
   mouse (lv 'mouse) (hand? _) (mouse != () && (ms 'on = 1 || look = ()))
   (mid _) (window-size win @ s [(s 0 // 2) (s 1 // 2)])
   (grab! on) (: c (mid ()) ok (window-hold win on)
     (on && ok ? (pins ms 'on 1 'dx 0 'dy 0, window-warp win (c 0) (c 1)) (pin ms 'on 0)))
   ; the terminal's size, and 80 by 24 off a tty that will not say; asked again every
   ; frame, so a resized window is painted whole
   (shape _) (? win (window-size win @ s [(max 20 (s 0 // 8)) (max 8 (s 1 // 16))])
                (tty 1 @ ws [(two? ws && 19 < <>ws ? <>ws 80) (two? ws && 7 < <ws ? <ws 24)]))
   sh0 (shape ())
   st (lv 'new (sh0 0) (2 * sh0 1))
   pn {'con () 'at [0 0]} gz {'g () 'on 1 'l0 0 't ()}
   (resize _) (shape () @ sh
               (: l (con-lay con (sh 0) (sh 1)) q (l 0) at [(q 0) (q 1)] pw (max 4 (q 2)) pr (max 2 (q 3)) _ (pin pn 'con (l 1))
                  (? (pw != st 'w || 2 * pr != st 'h || at != pn 'at)
                     (pin st 'pane (con 'on ? (slip-box (con 'ps) 'scene) ()), pin pn 'at at, pin gz 'g (),
                      lv 'size st pw pr, win ? 0 (say out (esc + "[2J"))))))
   held {}
   ; ..a held letter as shift has it now, either shift down, whichever was pressed first
   shifts {}
   (cased k) (? (65 <= k && k <= 90 || 97 <= k && k <= 122) (any (c \ shifts c = 1) [42 54] ? (k & 95) (k | 32)) k)
   (shift! d p) (: _ (pin shifts p d) (each (keys held) (c \ held c @ h (h != () && charm? (h 0) ? (pin held c [(cased (h 0)) (h 1)])))))
   rep (peep lv 'repeat view-repeat)
   (hold? k) (elem (binds k) (peep lv 'walking view-walking) && (peep lv 'held (_ \ 1)) st)
   ; ..thumbs: the left half a stick centred where it lands, its keys held like a keyboard's,
   ; the right half looking, and a touch that stays put a tap
   stick (lv 'stick) fg {}
   _ (stick && win ? (window-thumbs win) 0)
   ; ..a phone's console: a tap at the top's middle opens it and puts it away, as esc does; the
   ; keyboard up and its touches the panes' while it is up, the gpu let go, which would hide it
   pc {'on 0}
   (phone-con _) (: on (con 'on) gp (st 'gpu) (? (!phone || on = pc 'on) ()
     (: _ (pin pc 'on on) _ (each (keys fg) (i \ pin fg i ())) _ (each (keys held) (c \ pin held c ()))
        (on ? (: _ (tablet? gp && tablet? (gp 'g) ? ((cite 'gpu 'gpu-close) (gp 'g), pin st 'gpu 'off, pin pc 'gpu 1) 0) (pin win 'thumbs 0, window-typing win 1))
              (: _ (peep pc 'gpu 0 ? (pins pc 'gpu 0, pin st 'gpu ()) 0) (window-thumbs win))))))
   (phone-shut? e) (phone && con 'on && (<e = 'press ? (view-middle? st (e 2) (e 3)) (<e = 'down && e 1 = 1)))
   (axis slot want) (: old (held slot @ h (h != () ? <h ()))
     (? (want = old) ()
        (want = ()) (pin held slot (), ())
        (pin held slot [want (clock 0 + rep 0)], [want])))
   (finger [_ id a x y]) (: f (fg id)
     (? (a = 0) (pin fg id {'walk (x < <(window-size win) // 2) 'x0 x 'y0 y 'x x 'y y 'far 0}, ())
        !(tablet? f) ()
        (a = 2) (: dx (x - f 'x0) dy (y - f 'y0) d view-thumb-still
                   ks (? (f 'walk) (axis 'stick-x (? (dx < -d) (stick 2) (d < dx) (stick 3) ())
                                    + axis 'stick-y (? (#stick > 4 && dy < -view-thumb-run) (stick 4) (dy < -d) (stick 0) (d < dy) (stick 1) ()))
                         (: _ (pins ms 'dx (ms 'dx + view-thumb-look * (x - f 'x)) 'dy (ms 'dy + view-thumb-look * (y - f 'y))) ()))
                   (pins f 'x x 'y y 'far (f 'far || d < abs dx || d < abs dy ? 1 0), ks))
        (: mid (phone && !(f 'far) && view-middle? st x y) _ (mid ? (con-up con 1) 0)
           ks (f 'far || mid ? () (peep lv 'tap view-tap st x y))
           ((f 'walk ? (pins held 'stick-x () 'stick-y ())),
            pin fg id (),
            ks))))
   ; ..a window's keys: a key down is its code by what it typed, else by its place; the
   ; help's key let go puts the help away
   (wgo l) (? (atom? l) ()
              (: e <l nx (two? >l ? <>l ()) t (two? nx && <nx = 'text ? (nx 1) "")
                 k (? (0 < #t) (t 0) (view-set1 (e 1)))
                 (? (<e = 'close) ('quit . wgo >l)
                    (<e = 'finger) (finger e @ ks (ks + wgo >l))     ; in turn: a quick tap's up may ride with its down
                    (phone-shut? e) (con-up con 0, wgo >l)
                    (!(ms 'on && elem <e ['press 'move 'release]) && con-event con eval e t at (<e = 'down && charm? k && con? k)) (let-go (), wgo >l)
                    (<e = 'press && look && !(ms 'on)) (grab! 1, wgo >l)
                    (elem <e ['press 'release] && hand? ()) (mouse st <e (e 1), wgo >l)
                    (<e = 'move && ms 'on) (: c (mid ()) dx (e 1 - c 0) dy (e 2 - c 1)
                                              (pins ms 'dx (ms 'dx + dx) 'dy (ms 'dy + dy),
                                               (dx != 0 || dy != 0 ? (window-warp win (c 0) (c 1)) 0),
                                               wgo >l))
                    (elem (e 1) [42 54] && elem <e ['down 'up]) (shift! (<e = 'down ? 1 0) (e 1), wgo >l)
                    (<e = 'down && ms 'on && k = 27) (grab! 0, wgo >l)
                    (<e = 'down && charm? k && held (e 1) != ()) (wgo >l)
                    (<e = 'down && charm? k) (pin held (e 1) [k (clock 0 + rep 0)],
                                              (binds k @ 'help (pins hs 'on 1 'p (e 1))),
                                              k . wgo >l)
                    (<e = 'up) (pin held (e 1) (),
                                (e 1 = hs 'p ? (pins hs 'on 0 'p ())),
                                wgo >l)
                    (wgo >l))))
   ; ..a down for a key already held is the keyboard's repeat, which the pace here stands for
   ; ..and one due before this frame's events and still down after them acts again
   (wkeys _) (: now (clock 0)
               due (filter (c \ held c @ h (h != () && hold? (h 0) && h 1 <= now)) (sort (keys held)))
               pressed (wgo (con-events con win))
               again (filter (c \ held c != ()) due)
               _ (each again (c \ pin held c [(held c 0) (now + rep 1)]))
               (pressed + map (c \ held c 0) again))
   ; ..a terminal's: the last waiting; with the help up, any key puts it away and does no more
   (tkeys last) (cue? 0 ? (edkey in @ k (con-term con eval k (charm? k && con? k) @ q (tkeys (? (charm? q) q (con-keyed? con) () last)))) last)
   (tget _) (tkeys () @ k (? !(charm? k) ()
                             (hs 'on) (pin hs 'on 0, ())
                             (binds k = 'help) (pin hs 'on 1, ())
                             [k]))
   tick (1000 // lv 'fps)
   hn (horn song-rate 2 @ q (nom? q ? () q))
   fd (lv 'song hn)
   pace (pacer ())
   (feed _) (? (hn && fd) (song-keep hn pace song-lead (_ \ (fd st))) fd (fd st) 0)
   ; ..the pixel scale gauged where a picture's pixels are the scale's, a window's or kitty's,
   ; from the tenth frame, past the first ones' warming, until a key moves it by hand, and
   ; again from the scale it left when 'auto's key says; the
   ; horn low once what it holds would last under a frame and a quarter, the last one's, and falling
   scales [1 2 4 8]
   (gauged? _) (gz 'on && 10 <= st 't && (tablet? win || st 'kitty) && st 'pic-w != ())
   (steer paint feed l0 t) (: g (gz 'g @ () (: g0 (view-gauge [64 16 4 1] (scale-step (peep st 'scale 2)) (1.0 * tick)) (pin gz 'g g0, g0)) g g)
     per (gz 't @ () tick u (t - u))
     lw (hn && l0 * 1000 < 1.25 * per * song-rate && l0 < gz 'l0) i (g 'i)
     j (view-gauged g paint feed lw t)
     (pins gz 'l0 l0 't t, j != i ? (view-scaled lv st (scales j))))
   (scale-step s) (s @ 1 0 2 1 4 2 3)
   (go _) (: t0 (clock 0)
             l0 (hn ? (horn-lag hn) 0)
             _ (feed ())
             t1 (clock 0)
             ks (win ? (wkeys ()) (tget ()))
             acts (map (k \ k = 'quit ? 'quit (binds k)) ks)
             _ (look && (ms 'dx != 0 || ms 'dy != 0) ? (look st (ms 'dx) (ms 'dy), pins ms 'dx 0 'dy 0) 0)
             _ (phone-con ())
             _ (resize ())
             _ (pin st 'over (? !win {} (two? (pn 'con)) (view-box-bands st (con-box con (pn 'con))) (hs 'on) (view-help-bands st hl) {}))
             _ (win ? (lv 'frame st)
                    (lv 'frame st @ f (say out (esc + "[H" + (? (two? (pn 'con)) (view-synced (con-shift f (pn 'at 0) (pn 'at 1)) (view-box-say st (con-box con (pn 'con)))) (hs 'on) (view-synced f (view-help-say st hl)) f)), flush out)))
             _ (gauged? () ? (steer (clock 0 - t1) (t1 - t0) l0 (clock 0)))
             (each acts (a \ (? (elem a ['finer 'coarser]) (pin gz 'on 0, view-rescale lv st a)
                                (a = 'auto) (pins gz 'on 1 'g () 'l0 0 't ())
                                (nom? a && !(elem a ['quit 'help 'auto 'console])) (lv 'key st a))),
              lv 'tick st,
              pin st 't (st 't + 1),
              (? (st 'done && !(st 'done-at)) (pin st 'done-at (clock 0))),
              elem 'quit acts || st 'done-at && lv 'linger <= clock (st 'done-at) ? ()
                (clock 0 - t0 @ spent
                   (spent < tick ? (rest (tick - spent)),
                    go ()))))
   _ (win ? 0 (say out (esc + "[2J")))
   _ (go ())
   ; ..and the card goes back before the next level asks for it
   _ (hn ? (flush hn, close hn))
   ; done: the next level takes the stage as it stands and gives it back here; a seat
   ; that carries no such level ends where this one did
   nx (lv 'next) walk (nx ? (cite (nx 0) (nx 1)))
   (st 'done && walk ? (walk ()),
    st))
 ; ..and the verb around a walk: the screen raised here and put back here, taps on for
 ; the rove floors a walk hands over to
 (view-run walk) (ttytake rove-modes,
                  walk (),
                  ttygive rove-modes,
                  0)
 ; ..or a window, unless its words asked for the terminal: 640 by 400 and given back after,
 ; and one that can't be had is the terminal's unless it was asked for. walk takes o with
 ; 'win the window, and done answers what to say to the terminal once it is down. a phone
 ; holds it sideways, its keyboard down, from before the level is made
 (view-stage o walk done)
  (: asked (o 'md = 'window) (tty _) (view-run (_ \ walk o), done (), 0)
     (side on) ((cite 'droid 'droid-side) on)
     (? (!asked && (o 'md != () || !(window-here? ()))) (tty ())
        (side 1, window-open 640 400 "lore" @ win
           (? (tablet? win) (window-thumbs win,
                             mind (_ \ walk (pins o 'md 'window 'win win)) () (_ \ (window-close win, side 0)), 0)
              asked (side 0, say err ("lore: no window (" + show win + ")\n"), flush err, 1)
              (side 0, tty ())))))
 ; ..whether pixel x y is a top corner of st's window, and the tap that leaves by one
 (view-corner? st x y) (: ws (window-size (st 'win)) u (1.0 * x / <ws) v (1.0 * y / ws 1)
                          (v < 0.15 && (u < 0.15 || 0.85 < u)))
 ; ..the top's middle, a phone's console
 (view-middle? st x y) (: ws (window-size (st 'win)) u (1.0 * x / <ws) v (1.0 * y / ws 1) (v < 0.15 && 0.4 < u && u < 0.6))
 (view-tap st x y) (view-corner? st x y ? [113] ())
 ; --- a loading screen while a level is made: (view-loading win box draw) answers a tick,
 ;     (tick what part), for the making to call as it goes, what it is at and () or how far
 ;     through, 0.0 to 1.0. once the making has taken view-load-wait ms, and no oftener than
 ;     a frame after, draw is called with {'win 'box 'ms 'n 'fresh 'what 'part}, n its count,
 ;     fresh 1 on the first and when the box has changed since the last: in a window it
 ;     paints the paper inside box [x0 y0 x1 y1], in pixels, or () the whole window
 ;     as big as it is by then, and answers [y0 y1] the rows to show, or () for the box's;
 ;     the paper may not hold what the screen does, a window's frames being sent whole.
 ;     else box is in cells and it answers what to say to the terminal. under view-busy the
 ;     tick only notes where the making is, and the busy loop draws ---
 view-load-wait 150 view-load-every 40
 (view-loading win box draw) (: t0 (clock 0) at {'n 0 'last 0 'busy 0}
   (paint what part) (: now (clock 0)
     (? ((now - t0) < view-load-wait || (now - at 'last) < view-load-every) ()
        (: b (tablet? win && atom? box ? (window-sized win @ s [0 0 (s 0) (s 1)]) box)
           s (draw {'win win 'box b 'ms (now - t0) 'n (at 'n) 'fresh (at 'n = 0 || b != at 'box) 'what what 'part part})
           (pins at 'n (at 'n + 1) 'last now 'box b,
            (? (tablet? win) (s @ [y0 y1] (window-show win y0 y1) _ (window-show win (b 1) (b 3)))
               (string? s) (say out s, flush out)),
            ()))))
   (\ what part (what @
     'busy (pin at 'busy part, ())
     'spin (paint (at 'what) (at 'part))
     _ (pins at 'what what 'part part, at 'busy ? () (paint what part)))))
 ; ..(view-busy tk f) answers (f ()), made on a task of its own while this one draws tk's
 ; screen every view-load-every ms, whether the making ticks or not; a scare in the making
 ; scares here. tk () just makes it. a long call into C still holds both till it is back
 (view-busy tk f) (tk @ () (f ())
   _ (: w (twirl (_ \ trap (_ \ [1 (f ())]) () (a \ b \ [0 a b])) 0)
        (go _) (landed? w ? 0 (tk 'spin (), rest view-load-every, go ()))
        (tk 'busy 1, go (), tk 'busy 0, catch w @ r (<r = 1 ? (r 1) (scare (r 1) (r 2))))))
 ; ..a tick for win, or the terminal where it is (), its whole screen the box
 (view-tick win draw) (view-loading win (tablet? win ? ()
                         (tty 1 @ ws [0 0 (two? ws && 19 < <>ws ? <>ws 80) (two? ws && 7 < <ws ? <ws 24)])) draw)
 ; ..the loading screen a level has unless it says another: the box black, and in its middle
 ; the moon going through its phases, a month in view-spin-n draws, new to full lit from the
 ; right, drawn as pom draws it naturally from a camera circling it; in a terminal its eight
 ; faces, two cells wide
 view-spin-bg 0 view-spin-n 24
 view-spin-cells ["\u{1f311}" "\u{1f312}" "\u{1f313}" "\u{1f314}" "\u{1f315}" "\u{1f316}" "\u{1f317}" "\u{1f318}"]
 (view-spin ld) (: b (ld 'box) n (ld 'n) win (ld 'win) bw (b 2 - b 0) bh (b 3 - b 1)
   (? !(tablet? win) (esc + "[" + show ((b 1 + b 3) // 2 + 1) + ";" + show ((b 0 + b 2) // 2) + "H" + esc + "[0;37;40m"
            + view-spin-cells (n * 8 // view-spin-n % 8) + esc + "[0m")
      ; ..a fifth of the box across, drawn at most 64 pixels and blown up past that
      (: Q (min bw bh // 5) k (max 1 ((Q + 63) // 64)) S (Q // k) A (S * k) W (window-size win 0) P (window-paper win) bg view-spin-bg
         x0 (b 0 + (bw - A) // 2) y0 (b 1 + (bh - A) // 2)
         I (iota (2 S)) R (0.42 * S) x ((I % S - 0.5 * S + 0.5) / R) y ((I // S - 0.5 * S + 0.5) / R)
         in (2 x + 2 y < 1.0) f (bg + in * ((cite 'pom 'pom-orbit-at) ((n % view-spin-n) / (1.0 * view-spin-n)) x y - bg)) T (cask (2 A * 4))
         Z (cask (4 * bw))
         fr (peep ld 'fresh (n = 0)) _ (fr ? (each ^bh (j \ pour P (((b 1 + j) * W + b 0) * 4) Z 0 (4 * bw))))
         (S < 12 ? () (: _ (frame-paint f S k T A) _ (each ^A (j \ pour P (((y0 + j) * W + x0) * 4) T (j * A * 4) (A * 4)))
                         (fr ? () [y0 (y0 + A)]))))))
 ; ..a level's 'song: (new h sd) a song into the horn, fed (feed s) a frame; none on a
 ; seat with no horn
 (view-song new feed) (hn \ ((hn ? (new hn (wheel (clock 0)))) @ s (s ? (_ \ (feed s)))))
 ; ..24-bit where COLORTERM says the terminal takes it, else the 256 palette dithered
 (view-deep? _) (elem (getenv "COLORTERM") ["truecolor" "24bit"])
 ; --- a level's words: each rule, given the words left, answers [key value rest] for
 ;     those it reads off the front, or () where they are not its; the words in any order,
 ;     each key at most once -> a tablet, or () for a word no rule reads, a value read as
 ;     (), or a key said twice ---
 (view-words as rules) (: o {}
   (try l rs) (? (atom? rs) () (<rs l @ () (try l >rs) m m))
   (go l) (? (atom? l) o
             (try l rules @ [k v r] (v = () || o k != () ? () (pin o k v, go r))
                            _ ()))
   (go as))
 ; ..a word alone that says v of k, and a word whose next one (read w) reads
 (view-flag w k v) (l \ <l = w ? [k v >l])
 ; ..a window, by -w or --window
 view-window (l \ elem <l ["-w" "--window"] ? ['md 'window >l])
 (view-arg w k read) (l \ two? >l && <l = w ? [k (read <>l) >>l])
 ; ..--scale N, a picture's pixel N by N of the screen's, N a power of two to 8: fewer
 ; pixels drawn for more frames
 view-scale (view-arg "--scale" 'scale (w \ w @ "1" 1 "2" 2 "4" 4 "8" 8 ()))
 ; ..the verb: the words read, or the usage and 2 where they cannot be
 (view-main name usage opts run as) (opts as @ o
   (tablet? o ? (run o) (say err (name + ": " + usage + "\n"), flush err, 2))))
) ; module view
