; view -- what a first-person level in half blocks rides: the screen as a camera on the
; state, the rays its columns cast, the pens said a change at a time, the tty loop that
; runs a level, and the small arithmetic the scenes share. wade, dusk and shaft
; (apps/rove/) borrow it.
(module (view esc pi clamp flo wrap min2 max2 over throw sgr view! view-hz view-size view-rays
         view-frame view-walk view-run)
(borrow 'rove)                          ; the pacer, the horn's lead, the keys drained
(? (cite 'posix) (borrow 'posix) ())    ; close, for the horn
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
 (mash a) (: h (((a & m32) * 1103515245) & m32) h2 (((h ^ (h >> 15)) * 1664525) & m32) (h2 ^ (h2 >> 13)))
 (throw x y s k) ((mash (y * 374761393 + x * 668265263 + s * 2654435761 + 1)) % k)
 ; a pen on a ground as an sgr, kept once said
 sgrs {}
 (sgr f b) (: k (f * 256 + b) s (sgrs k)
              (string? s ? s (: s2 (esc + "[38;5;" + show f + ";48;5;" + show b + "m") (pin sgrs k s2, s2))))
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
   (row x f b ts bs bd) (? (x < w)
     (: tx (two? bd && bd 0 <= x < bd 0 + #(bd 1))
        f2 (tx ? (bd 2) (peep ts x 0)) b2 (tx ? (bd 3) (peep bs x 0))
        _ (f2 != f || b2 != b ? (say j (sgr f2 b2)))
        _ (say j (tx ? (string (bd 1 (x - bd 0))) "▀"))
        (row (x + 1) f2 b2 ts bs bd)))
   (rows y) (? (y < h // 2) (row 0 -1 -1 (src (2 * y)) (src (2 * y + 1)) (peep bands y ()),
                             say j (esc + "[0m"), (? ((y + 1) < (h // 2)) (say j "\r\n")), rows (y + 1)))
   (rows 0, slurp j))
 ; a level on a stage already raised, a frame a tick: every key waiting is read and the
 ; last one acts, so a held key moves once a frame; the horn is fed until a lead stands
 ; queued, the lead paced by the frame gap; the rest is what the tick has left after the
 ; painting. the level is lv: 'new (w h) its state, 'size (st w r) a resize, 'frame (st),
 ; 'key (st k), 'tick (st) a frame's own motion, 'fps, 'song (hn) what feeds its song a
 ; chunk (st) -- asked with () on a seat with no horn, and then fed once a frame --
 ; 'linger how long it stays once 'done, and 'next the [module walk] after it, or ()
 (view-walk lv) (:
   ; the terminal's size, and 80 by 24 off a tty that will not say; asked again every
   ; frame, so a resized window is painted whole
   (shape _) (: ws (tty 1) [(two? ws && 19 < <>ws ? <>ws 80) (two? ws && 7 < <ws ? <ws 24)])
   sh0 (shape ())
   st (lv 'new (sh0 0) (2 * sh0 1))
   (resize _) (: sh (shape ())
               (? (sh 0 != st 'w || 2 * sh 1 != st 'h)
                (lv 'size st (sh 0) (sh 1), say out (esc + "[2J"))))
   tick (1000 // lv 'fps)
   hn (: q (horn song-rate 2) (? (nom? q) () q))
   fd (lv 'song hn)
   pace (pacer ())
   (feed _) (? (hn && fd) (song-fill hn (song-lead-of (pace! pace)) (\ _ (fd st))) fd (fd st) 0)
   (keys last) (? (cue? 0) (edkey in @ (113 || 27) 'quit k (keys (charm? k ? k last))) last)
   (go _) (: t0 (clock 0)
             _ (feed ())
             _ (resize ())
             _ (say out (esc + "[H" + lv 'frame st), flush out)
             k (keys ())
             _ (? (charm? k) (lv 'key st k))
             _ (lv 'tick st)
             _ (pin st 't (st 't + 1))
             _ (? (st 'done && !(st 'done-at)) (pin st 'done-at (clock 0)))
             (? (k = 'quit || (st 'done-at && lv 'linger <= clock (st 'done-at))) ()
                (: spent (clock 0 - t0)
                   _ (spent < tick ? (rest (tick - spent)))
                   (go ()))))
   _ (say out (esc + "[2J"))
   _ (go ())
   ; ..and the card goes back before the next level asks for it
   _ (? hn (flush hn, close hn))
   ; done: the next level takes the stage as it stands and gives it back here; a seat
   ; that carries no such level ends where this one did
   nx (lv 'next) walk (? nx (cite (nx 0) (nx 1)) ())
   _ (? (st 'done && walk) (walk ()))
   st)
 ; ..and the verb around a walk: the screen raised here and put back here
 (view-run walk) (: _ (raw 1)
   _ (say out (esc + "[?1049h" + esc + "[?25l"))
   _ (walk ())
   _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"), flush out)
   _ (drain-keys ())
   _ (raw 0)
   0))
) ; module view
