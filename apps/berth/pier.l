; apps/berth/pier.l -- berth steps ashore: the terminal emulator in its own X window.
;
;   love pier [-f FONT.hex] [-display :N] [CMD ARG..]     CMD defaults to $SHELL, else sh
;
; the same moor as berth -- a child on a pty, its bytes through a quay screen -- but the
; screen is painted as pixels: `dye` lays a row into a 32bpp cask with the console's own
; painter (love/quay/paint.c, the one inle's framebuffer takes), so pier draws what the
; console draws -- truecolour, the faces, wide chars, sixel and kitty pictures, and a face
; off FONT.hex (apps/face.l) for what cp437 lacks. the rows the screen names dirty go out
; in PutImage bands over lux's wire. keys come back as KeyPress, keysym to terminal bytes;
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
   (pier-mkwin s win parent w h)                      ; CreateWindow: back pixel, and keys + expose + structure
    (x-w8 s 1, x-w8 s 0, x-w16 s 10, x-w32 s win, x-w32 s parent,
     x-w16 s 0, x-w16 s 0, x-w16 s w, x-w16 s h, x-w16 s 0, x-w16 s 1, x-w32 s 0,
     x-w32 s 2050, x-w32 s 0, x-w32 s 163841)
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
   ; a KeyPress -> what a terminal sends. shift (or caps lock, on a letter) takes the second
   ; column; ctrl folds @..~ onto C0; alt goes ahead as ESC; latin-1 and unicode keysyms go
   ; out as utf-8. a key with nothing to say is ""
   (pier-keybytes km kc st)
    (: p (peep km kc ())
       (? !(two? p) ""
          (: lower <p upper <>p
             letter (97 <= lower <= 122)
             sym (? (((st & 1) != 0) || (letter && ((st & 2) != 0))) (? (0 < upper) upper lower) lower)
             sp (peep pier-special sym ())
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
       rows (tablet 8)
       ds (pier-dirty sc)
       _ (map (\ y (? (y < r) (pin rows y 1) 0)) (? all (jot r) ds))
       _ (? (-1 < cur) (pin rows (cur // c) 1) 0)
       _ (? ((-1 < last) && (last != cur) && ((last // c) < r)) (pin rows (last // c) 1) 0)
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
       l2 (? (0 < d) (: _ (pin dirty () 0) (pier-paint s win gc depth bx fx face (d = 2) last)) last)
       _ (rest 8)                                    ; a keystroke's echo within ~10 ms
       (pier-paints s win gc depth bx fx face dirty l2))

   ; --- a resize: the window manager retiled us. a fresh grid and frame to fit, and the
   ;     pty learns its size (the kernel raises SIGWINCH) ---
   (pier-resize bx fx m dirty wp hp)
    (: r (max 1 (hp // 16)) c (max 2 (wp // 8))
       sc (peep bx () 0)
       (? ((r = gaze sc 1) && (c = gaze sc 2)) 0
          (: _ (pin bx () (screen (cask (screen () r c)) r c))
             _ (pin fx () (cask (((c * 8) * (r * 16)) * 4)))
             _ (settty m r c)
             (pin dirty () 2))))

   ; --- the watch: X events in the main task. the moor pumps the child in another and
   ;     seals the socket when the child hangs up, so x-next wakes with () and we leave ---
   (pier-watch s m km dl bx fx dirty)
    (: e (x-next s)
       (? !(two? e) ()
          (: code (ev-code e)
             _ (? (code = 2) (: b (pier-keybytes km (ev-detail e) (ev-state e))
                                (? (0 < #b) (say m b, flush m) 0))
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
                   _ (x-map s win, x-flush s)
                   km (pier-keysyms s (scr-mink sc) (scr-maxk sc))
                   p (hopen argv r c)
                   (? !(two? p) (: _ (close s) p)
                      (: bx (hbox p) m (hmas p) pid (hpid p)
                         fx {(cask (((c * 8) * (r * 16)) * 4))}
                         dirty {1}
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
