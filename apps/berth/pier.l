; apps/berth/pier.l -- berth steps ashore: the terminal emulator in its own X window.
;
;   love pier [-f FONT.hex] [-display :N] [CMD ARG..]     CMD defaults to $SHELL, else sh
;
; the same moor as berth -- a child on a pty, its bytes through a quay screen -- but the
; screen is painted as pixels: `dye` lays a row into a 32bpp cask with the console's own
; painter (love/quay/paint.c, the one inle's framebuffer takes), so pier draws what the
; console draws -- truecolour, the faces, wide chars, sixel and kitty pictures, and a face
; off FONT.hex (apps/face.l) for what cp437 lacks. the rows the screen names dirty go out
; in PutImage bands over lux's wire. keys come back as KeyPress, keysym to terminal bytes,
; and the pointer as the reports a program turns on (?1000 and kin, the `mouse` nif); a
; paste asks the X selection for its text and sends it, bracketed when ?2004 asks; a
; drag or a double or triple click selects (`select`), and pier holds the primary for it;
; a ConfigureNotify opens a fresh grid and tells the pty; WM_DELETE or the child's exit
; steps away.
(module '(pier pier pier-keybytes pier-keysyms pier-main)
(borrow 'xwire)
(borrow 'posix)
(borrow 'berth)
(borrow 'face)
(:
   ; --- the requests the wire does not carry: a window of ours, a GC, a title, the delete
   ;     protocol, and PutImage ---
   (pier-mkwin s win parent w h)                      ; CreateWindow: back pixel, and keys + buttons + moves + expose + structure
    (x-w8 s 1, x-w8 s 0, x-w16 s 10, x-w32 s win, x-w32 s parent,
     x-w16 s 0, x-w16 s 0, x-w16 s w, x-w16 s h, x-w16 s 0, x-w16 s 1, x-w32 s 0,
     x-w32 s 2050, x-w32 s 0, x-w32 s 163917)
   (pier-gc s gc win) (x-w8 s 55, x-w8 s 0, x-w16 s 4, x-w32 s gc, x-w32 s win, x-w32 s 0)
   (pier-title s win t)
    (: n #t
       (x-w8 s 18, x-w8 s 0, x-w16 s (6 + (n + x-pad4 n) // 4), x-w32 s win,
        x-w32 s 39, x-w32 s 31, x-w8 s 8, x-w8 s 0, x-w16 s 0, x-w32 s n, x-wpad s t))
   (pier-protocols s win)                             ; WM_PROTOCOLS = [WM_DELETE_WINDOW]; answers the atom
    (: pr (x-intern s "WM_PROTOCOLS") dl (x-intern s "WM_DELETE_WINDOW")
       _ (x-w8 s 18, x-w8 s 0, x-w16 s 7, x-w32 s win, x-w32 s pr, x-w32 s 4,
          x-w8 s 32, x-w8 s 0, x-w16 s 0, x-w32 s 1, x-w32 s dl)
       dl)
   ; PutImage of pixel rows y..y+n. a request's length is 16 bits of words, so a band holds
   ; at most 262112 bytes whatever the width: a wide window makes fat rows, and one request
   ; past the limit reads as opcodes to the server
   (pier-ship s win gc depth fb w y n)
    (: rb (w * 4)
       band (: v (262112 // rb) (? (v < 1) 1 (min 64 v)))
       (go y left) (? (left < 1) (x-flush s)
                      (: k (min band left) bytes (k * rb)
                         _ (x-w8 s 72, x-w8 s 2, x-w16 s (6 + bytes // 4), x-w32 s win, x-w32 s gc,
                            x-w16 s w, x-w16 s k, x-w16 s 0, x-w16 s y, x-w8 s 0, x-w8 s depth, x-w16 s 0)
                         _ (x-flush s)
                         _ (say s (snip fb (y * rb) ((y * rb) + bytes)))
                         (go (y + k) (left - k))))
       (go y n))

   ; --- the keyboard: keycode -> (sym shifted-sym), the whole table once ---
   (pier-keysyms s mink maxk)
    (: nkc ((maxk - mink) + 1)
       _ (x-w8 s 101, x-w8 s 0, x-w16 s 2, x-w8 s mink, x-w8 s nkc, x-w16 s 0, x-flush s)
       hdr (x-reply s)
       kpc (<hdr = 1 ? (hdr 1) 0)
       km (tablet 256)
       (go k) (? (k < nkc)
                 (: s0 (x-r32 s) s1 (? (1 < kpc) (x-r32 s) 0)
                    _ (x-skip s (4 * max 0 (kpc - 2)))
                    _ (pin km (mink + k) [s0 s1])
                    (go (k + 1)))
                 km)
       (go 0))

   ; the special keys' bytes, by keysym: xterm's
   pier-special {65293 "\r" 65421 "\r" 65288 "\x7f" 65289 "\t" 65056 "\e[Z" 65307 "\e"
                 65361 "\e[D" 65362 "\e[A" 65363 "\e[C" 65364 "\e[B"
                 65360 "\e[H" 65367 "\e[F" 65365 "\e[5~" 65366 "\e[6~" 65535 "\e[3~" 65379 "\e[2~"
                 65470 "\eOP" 65471 "\eOQ" 65472 "\eOR" 65473 "\eOS" 65474 "\e[15~"
                 65475 "\e[17~" 65476 "\e[18~" 65477 "\e[19~" 65478 "\e[20~" 65479 "\e[21~"
                 65480 "\e[23~" 65481 "\e[24~"}
   ; a KeyPress's keysym: shift (or caps lock, on a letter) takes the second column; 0 for none
   (pier-sym km kc st)
    (: p (peep km kc ())
       (? !(two? p) 0
          (: lower <p upper <>p
             letter (97 <= lower <= 122)
             (? (((st & 1) != 0) || (letter && ((st & 2) != 0))) (? (0 < upper) upper lower) lower))))
   ; a KeyPress -> what a terminal sends. ctrl folds @..~ onto C0; alt goes ahead as ESC;
   ; latin-1 and unicode keysyms go out as utf-8. a key with nothing to say is ""
   (pier-keybytes km kc st)
    (: sym (pier-sym km kc st)
       (? (sym = 0) ""
          (: sp (peep pier-special sym ())
             b (? (string? sp) sp
                  ((st & 4) && (64 <= sym <= 126)) (string (sym & 31))
                  ((st & 4) && (sym = 32)) (string 0)
                  (32 <= sym <= 126) (string sym)
                  (160 <= sym <= 255) (utf8 sym)
                  (16777216 <= sym <= 17891327) (utf8 (sym - 16777216))
                  "")
             (? (((st & 8) != 0) && (0 < #b)) ("\e" + b) b))))

   ; --- the painter: the rows the screen names dirty (wet reads and clears), the cursor's
   ;     row and the one it left, each dyed into the frame and shipped as runs of bands ---
   (pier-dirty sc)
    (: (bits d base i acc) (? (i < 32) (bits d base (i + 1) (? ((d >> i) & 1) ((base + i) . acc) acc)) acc)
       (go k acc) (? (k < 8) (go (k + 1) (bits (wet sc k) (32 * k) 0 acc)) acc)
       (go 0 ()))
   (pier-paint s win gc depth bx fx face all last)
    (: sc (peep bx () 0) fb (peep fx () 0)
       r (gaze sc 1) c (gaze sc 2) w (c * 8)
       cur (? ((gaze sc 3) & 1) (gaze sc 0) -1)
       v (gaze sc 8)                                 ; the view looks back v lines: rows show v down
       rows (tablet 8)
       ds (pier-dirty sc)
       _ (map (\ y (? (y < r) (pin rows y 1) 0)) (? all (jot r) ds))
       _ (? ((-1 < cur) && (((cur // c) + v) < r)) (pin rows ((cur // c) + v) 1) 0)
       _ (? ((-1 < last) && (last != cur) && (((last // c) + v) < r)) (pin rows ((last // c) + v) 1) 0)
       ys (sort (keys rows))
       _ (map (\ y (dye sc fb w y cur face)) ys)
       ; each run of rows one band
       (run a b rest) (? (two? rest)
                         (? (<rest = (b + 1)) (run a <rest >rest)
                            (: _ (pier-ship s win gc depth fb w (a * 16) (((b - a) + 1) * 16))
                               (run <rest <rest >rest)))
                         (pier-ship s win gc depth fb w (a * 16) (((b - a) + 1) * 16)))
       _ (? (two? ys) (run <ys <ys >ys) 0)
       cur)
   (pier-paints s win gc depth bx fx face dirty last)
    (: d (peep dirty () 0)
       l2 (? (0 < d)
             (: _ (pier-hold dirty) _ (pin dirty () 0)
                l (pier-paint s win gc depth bx fx face (d = 2) last)
                _ (pier-let dirty)
                l)
             last)
       _ (rest 8)                                    ; a keystroke's echo within ~10 ms
       (pier-paints s win gc depth bx fx face dirty l2))

   ; --- a resize: the window manager retiled us. the grid laid across to fit, a fresh
   ;     frame, and the pty learns its size (the kernel raises SIGWINCH) ---
   (pier-resize bx fx m dirty wp hp)
    (: r (max 1 (hp // 16)) c (max 2 (wp // 8))
       sc (peep bx () 0)
       (? ((r = gaze sc 1) && (c = gaze sc 2)) 0
          (: _ (pin bx () (regrid sc (cask (screen () r c)) r c))
             _ (pin fx () (cask (((c * 8) * (r * 16)) * 4)))
             _ (settty m r c)
             (pin dirty () 2))))

   ; --- the history: shift+PgUp/PgDn half a screen, the wheel three lines; any other key
   ;     brings the view home before its bytes go ---
   (pier-peer bx dirty n)
    (: sc (peep bx () 0)
       _ (peer sc (max 0 ((gaze sc 8) + n)))
       (pin dirty () 1))
   (pier-key s m km bx dirty kc st)
    (: sym (pier-sym km kc st) sc (peep bx () 0) half (max 1 ((gaze sc 1) // 2))
       (? (((st & 1) != 0) && (sym = 65365)) (pier-peer bx dirty half)
          (((st & 1) != 0) && (sym = 65366)) (pier-peer bx dirty (0 - half))
          (((st & 1) != 0) && (sym = 65379)) (pier-ask s dirty 1 (peep dirty 'utf8 0))           ; shift+Insert: the primary
          (((st & 5) = 5) && ((sym = 86) || (sym = 118))) (pier-ask s dirty (peep dirty 'clip 0) (peep dirty 'utf8 0))   ; ctrl+shift+V: the clipboard
          (: b (pier-keybytes km kc st)
             (? (0 < #b)
                (: _ (? (0 < gaze sc 8) (pier-peer bx dirty (0 - gaze sc 8)) 0)
                   (say m b, flush m))
                0))))

   ; --- the pointer: a press, a release or a move goes to the program when it asked for
   ;     them. unasked, the wheel scrolls the history, or on the alternate screen sends
   ;     three arrows, which a pager or an editor takes as scrolling, and the middle button
   ;     pastes the primary. a move is sent once per cell ---
   pier-xbtn {1 0 2 1 3 2 4 64 5 65 6 66 7 67}         ; X's button -> the report's
   (pier-mods st) ((? (st & 1) 4 0) + (? (st & 8) 8 0) + (? (st & 4) 16 0))
   (pier-held st) (? (st & 256) 0 (st & 512) 1 (st & 1024) 2 3)
   (pier-at raw k d n) (: v (u16 raw k) (? (32767 < v) 0 (min (n - 1) (v // d))))   ; a signed pixel -> a cell
   (pier-mouse s m bx dirty code raw)
    (: sc (peep bx () 0) st (u16 raw 28)
       row (pier-at raw 26 16 (gaze sc 1)) col (pier-at raw 24 8 (gaze sc 2))
       b (? (code = 6) (pier-held st) (peep pier-xbtn (raw 1) 3))
       at ((row * 65536) + col)
       mine (((st & 1) != 0) || !((gaze sc 3) & 7680))   ; unasked, or shift: the button is pier's
       (? ((code = 6) && (at = peep dirty 'at -1)) 0
          (: _ (? (code = 6) (pin dirty 'at at) 0)
             r (? mine "" (mouse sc (b + pier-mods st) row col (code - 4)))
             (? (0 < #r) (say m r, flush m)
                ((code = 4) && (64 <= b <= 65))
                 (? ((gaze sc 3) & 256) (say m (cats (map (\ _ (? (b = 64) "\e[A" "\e[B")) (jot 3))), flush m)
                    (pier-peer bx dirty (? (b = 64) 3 -3)))
                ((code = 4) && (b = 1)) (pier-ask s dirty 1 (peep dirty 'utf8 0))
                (mine && (b = 0)) (pier-choose s sc dirty code raw (((row - gaze sc 8) * gaze sc 2) + col))
                0))))

   ; --- the selection: a press anchors it (a second or third in quick succession on the
   ;     same cell takes the word or the line), a drag stretches it, and a release with
   ;     something chosen takes the primary, the text kept as it was then ---
   (pier-choose s sc dirty code raw gi)
    (: t (u32 raw 4)
       (? (code = 4)
          (: n (? (((t - peep dirty 'tp 0) < 400) && (gi = peep dirty 'anchor ())) (min 3 ((peep dirty 'clicks 0) + 1)) 1)
             _ (pins dirty 'tp t 'anchor gi 'clicks n 'unit (n - 1))
             _ (select sc gi gi (? (1 < n) (n - 1) -1))
             (pin dirty () 1))
          (code = 6)
          (: _ (select sc (peep dirty 'anchor gi) gi (peep dirty 'unit 0)) (pin dirty () 1))
          (? ((gaze sc 10) < (gaze sc 11))
             (: _ (pin dirty 'held (copied sc (gaze sc 10) (gaze sc 11)))
                _ (pier-hold dirty)
                _ (x-w8 s 22, x-w8 s 0, x-w16 s 4, x-w32 s (peep dirty 'win 0), x-w32 s 1, x-w32 s t, x-flush s)
                (pier-let dirty))
             0)))
   ; another client asks for the primary: as utf-8 or latin-1 text, or which targets there are.
   ; the answer rides a property of the asker's and a SelectionNotify
   (pier-serve s dirty raw)
    (: rq (u32 raw 12) sel (u32 raw 16) ty (u32 raw 20) pr0 (u32 raw 24)
       pr (? (pr0 = 0) ty pr0) tx (peep dirty 'held ()) ut (peep dirty 'utf8 0) tg (peep dirty 'targets 0)
       (prop tp fmt n bs) (: nb #bs
                            (x-w8 s 18, x-w8 s 0, x-w16 s (6 + (nb + x-pad4 nb) // 4), x-w32 s rq, x-w32 s pr,
                             x-w32 s tp, x-w8 s fmt, x-w8 s 0, x-w16 s 0, x-w32 s n, x-wpad s bs))
       (le4 v) (cats (map (\ k (string ((v >> (8 * k)) & 255))) (jot 4)))
       _ (pier-hold dirty)
       ok (? (sel != 1) 0
             (ty = tg) (: _ (prop 4 32 3 (le4 tg + le4 ut + le4 31)) 1)
             ((string? tx) && ((ty = ut) || (ty = 31)) && (#tx < 262000)) (: _ (prop ty 8 #tx tx) 1)
             0)
       _ (x-w8 s 25, x-w8 s 0, x-w16 s 11, x-w32 s rq, x-w32 s 0,
          x-w8 s 31, x-w8 s 0, x-w16 s 0, x-w32 s (u32 raw 4), x-w32 s rq, x-w32 s sel,
          x-w32 s ty, x-w32 s (? ok pr 0), x-w32 s 0, x-w32 s 0, x-flush s)
       (pier-let dirty))
   ; another client took the primary: the highlight goes
   (pier-lost bx dirty raw)
    (? ((u32 raw 12) = 1)
       (: _ (select (peep bx () 0) 0 0 -1) _ (pin dirty 'held ()) (pin dirty () 1))
       0)

   ; --- the socket has two writers, the painter and the watch: a turn runs from a
   ;     request's first byte to its flush ---
   (pier-hold dirty) (? (0 < peep dirty 'x 0) (: _ (rest 1) (pier-hold dirty)) (pin dirty 'x 1))
   (pier-let dirty) (pin dirty 'x 0)

   ; --- paste: the selection is asked for as utf-8 onto a property of ours (latin-1 when
   ;     the owner has no utf-8), and its SelectionNotify says where it landed. it goes to
   ;     the child as `pasted` lays it, and brings the view home as a key does ---
   (pier-ask s dirty sel ty)
    (: _ (pier-hold dirty)
       _ (x-w8 s 24, x-w8 s 0, x-w16 s 6, x-w32 s (peep dirty 'win 0), x-w32 s sel, x-w32 s ty,
          x-w32 s (peep dirty 'prop 0), x-w32 s 0, x-flush s)
       (pier-let dirty))
   (pier-send m bx dirty t)
    (: sc (peep bx () 0)
       _ (? (0 < gaze sc 8) (pier-peer bx dirty (0 - gaze sc 8)) 0)
       (say m (pasted sc t), flush m))
   (pier-got s m bx dirty raw)
    (: sel (u32 raw 12) ty (u32 raw 16) pr (u32 raw 20)
       (? (pr = 0) (? (ty = peep dirty 'utf8 0) (pier-ask s dirty sel 31) 0)
          (: _ (pier-hold dirty)
             _ (x-w8 s 20, x-w8 s 1, x-w16 s 6, x-w32 s (peep dirty 'win 0), x-w32 s pr,   ; GetProperty, deleting
                x-w32 s 0, x-w32 s 0, x-w32 s 262144, x-flush s)
             _ (pier-let dirty)
             hdr (x-reply s)
             (? !(<hdr = 1) 0
                (: bs (take (u32 hdr 16) (x-rbytes s (4 * u32 hdr 4)))
                   (? (((hdr 1) != 8) || !(two? bs)) 0
                      (pier-send m bx dirty (? (ty = 31) (cats (map utf8 bs)) (string bs)))))))))

   ; --- the watch: X events in the main task. the moor pumps the child in another and
   ;     seals the socket when the child hangs up, so x-next wakes with () and we leave ---
   (pier-watch s m km dl bx fx dirty)
    (: e (x-next s)
       (? !(two? e) ()
          (: code (ev-code e)
             _ (? (code = 2) (pier-key s m km bx dirty (ev-detail e) (ev-state e))
                  (4 <= code <= 6) (pier-mouse s m bx dirty code (ev-raw e))
                  (code = 31) (pier-got s m bx dirty (ev-raw e))
                  (code = 30) (pier-serve s dirty (ev-raw e))
                  (code = 29) (pier-lost bx dirty (ev-raw e))
                  (code = 12) (pin dirty () 2)
                  (code = 22) (: raw (ev-raw e) (pier-resize bx fx m dirty (u16 raw 20) (u16 raw 22)))
                  0)
             (? ((code = 33) && (dl = u32 (ev-raw e) 12)) () (pier-watch s m km dl bx fx dirty)))))

   ; --- pier: argv tied up at the shore, on display socket path, the face () or a laid one.
   ;     answers the child's status pair, or a nom naming what refused ---
   (pier argv path auth face)
    (: s (x-connect path)
       (? !(hot? s) 'no-display
          (: sc (x-setup s auth)
             (? !(two? sc) (: _ (close s) 'refused)
                (: win (scr-idbase sc) gc (scr-idbase sc + 1) depth (scr-depth sc)
                   r 24 c 80
                   _ (pier-mkwin s win (scr-root sc) (c * 8) (r * 16))
                   _ (pier-gc s gc win)
                   _ (pier-title s win "pier")
                   dl (pier-protocols s win)
                   ut (x-intern s "UTF8_STRING") cb (x-intern s "CLIPBOARD") pp (x-intern s "PIER_PASTE")
                   tg (x-intern s "TARGETS")
                   _ (x-map s win, x-flush s)
                   km (pier-keysyms s (scr-mink sc) (scr-maxk sc))
                   p (hopen argv r c)
                   (? !(two? p) (: _ (close s) p)
                      (: bx (hbox p) m (hmas p) pid (hpid p)
                         fx {(cask (((c * 8) * (r * 16)) * 4))}
                         dirty {1}                   ; the painter's cue at (), and what the tasks share
                         _ (pins dirty 'win win 'utf8 ut 'clip cb 'prop pp 'targets tg)
                         up (twirl (\ _ (: _ (moor bx m dirty) (seal s 0))) 0)
                         pnt (twirl (\ _ (pier-paints s win gc depth bx fx face dirty -1)) 0)
                         _ (pier-watch s m km dl bx fx dirty)
                         _ (freeze pnt)
                         _ (? (landed? up) (catch up) (: _ (still pid 15) (freeze up)))
                         _ (close s)
                         _ (close m)
                         (waitfor pid))))))))

   ; --- the verb ---
   pier-usage "usage: love pier [-f FONT.hex] [-display :N] [CMD ARG..]"
   (pier-main as)
    (: (opt a k d) (? (one? a) d (<a = k && two? >a) <>a (opt >a k d))
       (rest2 a) (? (one? a) () (elem <a ["-f" "-display"]) (rest2 >>a) a)
       disp (opt as "-display" (getenv "DISPLAY"))
       dn (: d (string? disp ? disp "") b (? (1 < #d) (snip d 1 #d) "0")
             (: (go i) (? ((i = #b) || (b i = 46)) (snip b 0 i) (go (i + 1))) (go 0)))
       fp (opt as "-f" ())
       face (? (string? fp) (: t (uread fp) (? (two? t) (face-hex <>t) ())) ())
       argv (: a (rest2 as) (? (two? a) a [(: sh (getenv "SHELL") (? (0 < #sh) sh "sh"))]))
       home (getenv "HOME")
       xa (: v (getenv "XAUTHORITY") (? (0 < #v) v (home + "/.Xauthority")))
       st (pier argv ("/tmp/.X11-unix/X" + dn) (xauth-cookie xa dn) face)
       (? (two? st) <st (: _ (say err ("pier: " + show st + "\n")) 1)))

   door (udoor 'pier pier-main pier-usage 1 1)
   _ (pins (cite 'verbs 'tab) 'pier door)
   s (cite 'verbs 'fire ["pier" "pier.l"])
   _ (two? s ? (quit (door >s)) 0))
) ; module pier
