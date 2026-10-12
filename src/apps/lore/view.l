; view -- what a first-person level in half blocks rides: the screen as a camera on the
; state, the rays its columns cast, the pens said a change at a time, the tty loop that
; runs a level, and the small arithmetic the scenes share. a scene that colours every
; pixel says its colours as pens here too: 24-bit, or the 256 palette dithered.
(module (view esc pi clamp flo wrap min2 max2 over throw sgr view! view-hz view-size view-rays
         view-frame view-walk view-run view-bayer view-deep-pens view-cube-pens view-deep-frame
         view-deep? view-words view-flag view-arg view-main view-song view-stage view-set1)
(borrow 'rove)                          ; the pacer, the horn's lead, the keys drained
(borrow 'window)                        ; a level in a window of its own, its keys held
(borrow 'posix)    ; close, for the horn
(:
 esc (string 27)
 pi 3.141592653589793
 (clamp v lo hi) (v < lo ? lo (hi < v ? hi v))
 (flo v) (int (v + 1000.0) - 1000)
 (wrap a) (a < -pi ? (wrap (a + 2.0 * pi)) (pi < a ? (wrap (a - 2.0 * pi)) a))
 (min2 a b) (a < b ? a b)
 (max2 a b) (a < b ? b a)
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
   (rows y) (y < h // 2 ? (row 0 -1 -1 (src (2 * y)) (src (2 * y + 1)) (peep bands y ()),
                           say j (esc + "[0m"), y + 1 < h // 2 ? (say j "\r\n"), rows (y + 1)))
   (rows 0, slurp j))
 ; --- colours to pens: c a triple of trays, each part 0 to 1 ---
 (sat1 v) (min 1.0 (max 0.0 v))
 ; each pixel's place in a 4 by 4 bayer square, a w by h screen's worth, as the dither's
 ; offset between two steps
 bayer (star-tray [16] [0 8 2 10 12 4 14 6 3 11 1 9 15 7 13 5])
 (view-bayer w h) (: i (iota (w * h)) (peep bayer (i // w % 4 * 4 + i % w % 4) 0 / 16.0 + 1.0 / 32.0))
 ; 24-bit, six bits a channel packed
 (view-deep-pens c) (: (q v) (int (sat1 v * 63.0 + 0.5)) (q (c 0) * 4096 + q (c 1) * 64 + q (c 2)))
 ; ..or the 256 palette's cube or grey ramp, dithered between its steps by bay
 (view-cube-pens c bay) (: (lv v) (sat1 v * 255.0 @ u (over (u / 95.0) (95.0 <= u) (1.0 + (u - 95.0) / 40.0)))
   (ix v) (max 0 (min 5 (floor (lv v + bay))))
   r (c 0) g (c 1) bl (c 2)
   chroma (max r (max g bl) - min r (min g bl))
   y (sat1 (0.299 * r + 0.587 * g + 0.114 * bl) * 255.0)
   gi (floor ((y - 8.0) / 10.0 + bay))
   grey (over (232 + max 0 (min 23 gi)) (gi < 0) 16)
   cube (16 + 36 * ix r + 6 * ix g + ix bl)
   (over cube (chroma < 0.05) grey))
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
   (rows y) (y < h // 2 ? (row 0 -1 -1 (2 * y * w) (peep bands y ()),
                           say j (esc + "[0m"), y + 1 < h // 2 ? (say j "\r\n"), rows (y + 1)))
   (rows 0, slurp j))
 ; a key in a window, by its place -> the key a terminal would have sent for it: the
 ; letters, the digits, space, and the arrows as the cli's numbers; q and esc 'quit
 view-set1 {16 'quit 1 'quit 57 32 331 -1 333 -2 328 -8 336 -9
            17 119 18 101 19 114 20 116 21 121 22 117 23 105 24 111 25 112
            30 97 31 115 32 100 33 102 34 103 35 104 36 106 37 107 38 108
            44 122 45 120 46 99 47 118 48 98 49 110 50 109
            2 49 3 50 4 51 5 52 6 53 7 54 8 55 9 56 10 57 11 48}
 ; ..and the walking ones, which act every frame they are held
 walking [104 106 107 108 117 110 -1 -2 -8 -9]
 ; a level on a stage already raised, a frame a tick: every key waiting is read and the
 ; last one acts, so a held key moves once a frame; the horn is fed until a lead stands
 ; queued, the lead paced by the frame gap; the rest is what the tick has left after the
 ; painting. the level is lv: 'new (w h) its state, 'size (st w r) a resize, 'frame (st),
 ; 'key (st k), 'tick (st) a frame's own motion, 'fps, 'song (hn) what feeds its song a
 ; chunk (st) -- asked with () on a seat with no horn, and then fed once a frame --
 ; 'linger how long it stays once 'done, and 'next the [module walk] after it, or ()
 ; in a window, 'win: the frame paints the window itself (mesh-show), the cells are 8 by 16
 ; of its pixels, each key pressed acts once and a walking key held acts every frame after,
 ; unless 'held (st) says not now
 (view-walk lv) (:
   win (peep lv 'win ())
   ; the terminal's size, and 80 by 24 off a tty that will not say; asked again every
   ; frame, so a resized window is painted whole
   (shape _) (? win (window-size win @ s [(max2 20 (s 0 // 8)) (max2 8 (s 1 // 16))])
                (tty 1 @ ws [(two? ws && 19 < <>ws ? <>ws 80) (two? ws && 7 < <ws ? <ws 24)]))
   sh0 (shape ())
   st (lv 'new (sh0 0) (2 * sh0 1))
   (resize _) (shape () @ sh
               (sh 0 != st 'w || 2 * sh 1 != st 'h ?
                (lv 'size st (sh 0) (sh 1), win ? 0 (say out (esc + "[2J")))))
   held {}
   (hold? k) (elem k walking && (peep lv 'held (_ \ 1)) st)
   (wkeys _) (: ev (window-events win)
               pressed (cats (map (e \ (? (<e = 'close) ['quit]
                                          (<e != 'down) ()
                                          (peep view-set1 (e 1) () @ () () k (pin held (e 1) k, [k]))))
                                  ev))
               _ (each ev (e \ (<e = 'up ? (pin held (e 1) ()))))
               again (filter (k \ hold? k && !(elem k pressed)) (filter (k \ k != ()) (map held (sort (keys held)))))
               (pressed + again))
   tick (1000 // lv 'fps)
   hn (horn song-rate 2 @ q (nom? q ? () q))
   fd (lv 'song hn)
   pace (pacer ())
   (feed _) (? (hn && fd) (song-fill hn (song-lead-of (pace! pace)) (_ \ (fd st))) fd (fd st) 0)
   (tkeys last) (cue? 0 ? (edkey in @ (113 || 27) 'quit k (tkeys (charm? k ? k last))) last)
   (go _) (: t0 (clock 0)
             _ (feed ())
             ks0 (win ? (wkeys ()) ())
             _ (resize ())
             _ (win ? (lv 'frame st) (say out (esc + "[H" + lv 'frame st), flush out))
             ks (win ? ks0 (tkeys () @ k (? (charm? k) [k] (k = 'quit) ['quit] ())))
             k (elem 'quit ks ? 'quit ())
             (each ks (k \ (charm? k ? (lv 'key st k))),
              lv 'tick st,
              pin st 't (st 't + 1),
              (? (st 'done && !(st 'done-at)) (pin st 'done-at (clock 0))),
              k = 'quit || st 'done-at && lv 'linger <= clock (st 'done-at) ? ()
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
                  drain-keys (),
                  ttygive rove-modes,
                  0)
 ; ..or the window its words asked for, 640 by 400 and given back after; walk takes o with
 ; 'win the window, and done answers what to say to the terminal once it is down
 (view-stage o walk done)
  (? (o 'md != 'window) (view-run (_ \ walk o), done (), 0)
     (window-open 640 400 "lore" @ win
        (? !(tablet? win) (say err ("lore: no window (" + show win + ")\n"), flush err, 1)
           (mind (_ \ walk (pin o 'win win)) () (_ \ window-close win), 0))))
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
 (view-arg w k read) (l \ two? >l && <l = w ? [k (read <>l) >>l])
 ; ..the verb: the words read, or the usage and 2 where they cannot be
 (view-main name usage opts run as) (opts as @ o
   (tablet? o ? (run o) (say err (name + ": " + usage + "\n"), flush err, 2))))
) ; module view
