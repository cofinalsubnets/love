; src/apps/mitty/pier.l -- mitty steps ashore: the terminal emulator in its own X window.
;
;   love pier [-f FONT.hex] [-display :N] [CMD ARG..]     CMD defaults to $SHELL, else sh
;
; the same moor as mitty -- a child on a pty, its bytes through a quay screen -- but the
; screen is painted as pixels: `dye` lays a row into a 32bpp cask with the console's own
; painter (src/love/quay/paint.c, the one inle's framebuffer takes), so pier draws what the
; console draws -- truecolour, the faces, wide chars, sixel and kitty pictures, and a font
; off FONT.hex (src/apps/font.l) for what cp437 lacks. the rows the screen names dirty go out
; in PutImage bands over lux's wire. keys come back as KeyPress, keysym to terminal bytes,
; and the pointer as the reports a program turns on (?1000 and kin, the `mouse` nif); a
; paste asks the X selection for its text and sends it, bracketed when ?2004 asks; a
; drag or a double or triple click selects (`select`) and a right click or a shift click
; stretches it, pier holding the primary for it and the clipboard on ctrl+shift+C;
; a ConfigureNotify opens a fresh grid and tells the pty; WM_DELETE or the child's exit
; steps away.
(module '(pier pier pier-keybytes pier-keysyms pier-main)
(borrow 'xwire)
(borrow 'posix)
(borrow 'mitty)
(borrow 'font)
(:
   ; --- the requests the wire does not carry: a window of ours, a GC, a title, the delete
   ;     protocol, and PutImage ---
   (pier-mkwin s win parent w h)                      ; CreateWindow: back pixel, and keys + buttons + moves + expose + structure + property
    (x-w8 s 1, x-w8 s 0, x-w16 s 10, x-w32 s win, x-w32 s parent,
     x-w16 s 0, x-w16 s 0, x-w16 s w, x-w16 s h, x-w16 s 0, x-w16 s 1, x-w32 s 0,
     x-w32 s 2050, x-w32 s 0, x-w32 s 4358221)
   (pier-gc s gc win) (x-w8 s 55, x-w8 s 0, x-w16 s 4, x-w32 s gc, x-w32 s win, x-w32 s 0)
   (pier-title s win t)
    (#t @ n
       (x-w8 s 18, x-w8 s 0, x-w16 s (6 + (n + x-pad4 n) // 4), x-w32 s win,
        x-w32 s 39, x-w32 s 31, x-w8 s 8, x-w8 s 0, x-w16 s 0, x-w32 s n, x-wpad s t))
   (pier-protocols s win)                             ; WM_PROTOCOLS = [WM_DELETE_WINDOW]; answers the atom
    (: pr (x-intern s "WM_PROTOCOLS") dl (x-intern s "WM_DELETE_WINDOW")
       ((x-w8 s 18, x-w8 s 0, x-w16 s 7, x-w32 s win, x-w32 s pr, x-w32 s 4,
         x-w8 s 32, x-w8 s 0, x-w16 s 0, x-w32 s 1, x-w32 s dl),
        dl))
   ; PutImage of pixel rows y..y+n. a request's length is 16 bits of words, so a band holds
   ; at most 262112 bytes whatever the width: a wide window makes fat rows, and one request
   ; past the limit reads as opcodes to the server
   (pier-ship s win gc depth fb w y n)
    (: rb (w * 4)
       band (262112 // rb @ v (v < 1 ? 1 (min 64 v)))
       (go y left) (left < 1 ? (x-flush s)
                      (: k (min band left) bytes (k * rb)
                         ((x-w8 s 72, x-w8 s 2, x-w16 s (6 + bytes // 4), x-w32 s win, x-w32 s gc,
                           x-w16 s w, x-w16 s k, x-w16 s 0, x-w16 s y, x-w8 s 0, x-w8 s depth, x-w16 s 0),
                          x-flush s,
                          say s (snip fb (y * rb) (y * rb + bytes)),
                          go (y + k) (left - k))))
       (go y n))

   ; --- the keyboard: keycode -> (sym shifted-sym), the whole table once ---
   (pier-keysyms s mink maxk)
    (: nkc (maxk - mink + 1)
       _ (x-w8 s 101, x-w8 s 0, x-w16 s 2, x-w8 s mink, x-w8 s nkc, x-w16 s 0, x-flush s)
       hdr (x-reply s)
       kpc (<hdr = 1 ? (hdr 1) 0)
       km (tablet 256)
       (go k) (k < nkc ?
                 (: s0 (x-r32 s) s1 (1 < kpc ? (x-r32 s) 0)
                    (x-skip s (4 * max 0 (kpc - 2)),
                     pin km (mink + k) [s0 s1],
                     go (k + 1)))
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
    (peep km kc () @ p
       (? !(two? p) 0
          (: lower <p upper <>p
             letter (97 <= lower <= 122)
             (st & 1 != 0 || letter && st & 2 != 0 ? (0 < upper ? upper lower) lower))))
   ; a KeyPress -> what a terminal sends. ctrl folds @..~ onto C0; alt goes ahead as ESC;
   ; latin-1 and unicode keysyms go out as utf-8. a key with nothing to say is ""
   (pier-keybytes km kc st)
    (pier-sym km kc st @ sym
       (sym = 0 ? ""
          (: sp (peep pier-special sym ())
             b (? (string? sp) sp
                  (st & 4 && 64 <= sym <= 126) (string (sym & 31))
                  (st & 4 && sym = 32) (string 0)
                  (32 <= sym <= 126) (string sym)
                  (160 <= sym <= 255) (utf8 sym)
                  (16777216 <= sym <= 17891327) (utf8 (sym - 16777216))
                  "")
             (st & 8 != 0 && 0 < #b ? ("\e" + b) b))))

   ; --- the painter: the rows the screen names dirty (wet reads and clears), the cursor's
   ;     row and the one it left, each dyed into the frame and shipped as runs of bands ---
   (pier-dirty sc)
    (: (bits d base i acc) (i < 32 ? (bits d base (i + 1) (d >> i & 1 ? ((base + i) . acc) acc)) acc)
       (go k acc) (k < 8 ? (go (k + 1) (bits (wet sc k) (32 * k) 0 acc)) acc)
       (go 0 ()))
   (pier-paint s win gc depth bx fx font all last)
    (: sc (peep bx () 0) fb (peep fx () 0)
       r (gaze sc 1) c (gaze sc 2) w (c * 8)
       cur (gaze sc 3 & 1 ? (gaze sc 0) -1)
       v (gaze sc 8)                                 ; the view looks back v lines: rows show v down
       rows (tablet 8)
       ds (pier-dirty sc)
       _ (map (y \ (y < r ? (pin rows y 1) 0)) (all ? (jot r) ds))
       _ (-1 < cur && cur // c + v < r ? (pin rows (cur // c + v) 1) 0)
       _ (-1 < last && last != cur && last // c + v < r ? (pin rows (last // c + v) 1) 0)
       ys (sort (keys rows))
       _ (map (y \ dye sc fb w y cur font) ys)
       ; each run of rows one band
       (run a b rest) (two? rest ?
                         (<rest = b + 1 ? (run a <rest >rest)
                            (pier-ship s win gc depth fb w (a * 16) ((b - a + 1) * 16),
                             run <rest <rest >rest))
                         (pier-ship s win gc depth fb w (a * 16) ((b - a + 1) * 16)))
       (two? ys ? (run <ys <ys >ys) 0,
        cur))
   (pier-paints s win gc depth bx fx font dirty last)
    (: d (peep dirty () 0)
       l2 (0 < d ?
             (: _ (pier-hold dirty) _ (pin dirty () 0)
                l (pier-paint s win gc depth bx fx font (d = 2) last)
                (pier-let dirty,
                 l))
             last)
       (rest 8,                                      ; a keystroke's echo within ~10 ms
        pier-paints s win gc depth bx fx font dirty l2))

   ; --- a resize: the window manager retiled us. the grid laid across to fit, a fresh
   ;     frame, and the pty learns its size (the kernel raises SIGWINCH) ---
   (pier-resize bx fx m dirty wp hp)
    (: r (max 1 (hp // 16)) c (max 2 (wp // 8))
       sc (peep bx () 0)
       (r = gaze sc 1 && c = gaze sc 2 ? 0
          (pin bx () (regrid sc (cask (screen () r c)) r c),
           pin fx () (cask (c * 8 * (r * 16) * 4)),
           settty m r c,
           pin dirty () 2)))

   ; --- the history: shift+PgUp/PgDn half a screen, the wheel three lines; any other key
   ;     brings the view home before its bytes go ---
   (pier-peer bx dirty n)
    (peep bx () 0 @ sc
       (peer sc (max 0 (gaze sc 8 + n)),
        pin dirty () 1))
   (pier-key s m km bx dirty kc st raw)
    (: sym (pier-sym km kc st) sc (peep bx () 0) half (max 1 (gaze sc 1 // 2))
       (? (st & 1 != 0 && sym = 65365) (pier-peer bx dirty half)
          (st & 1 != 0 && sym = 65366) (pier-peer bx dirty (0 - half))
          (st & 1 != 0 && sym = 65379) (pier-ask s dirty 1 (peep dirty 'utf8 0))                 ; shift+Insert: the primary
          (st & 5 = 5 && (sym = 86 || sym = 118)) (pier-ask s dirty (peep dirty 'clip 0) (peep dirty 'utf8 0))           ; ctrl+shift+V: the clipboard
          (st & 5 = 5 && (sym = 67 || sym = 99))                                       ; ctrl+shift+C: the selection onto it
           (gaze sc 10 < gaze sc 11 ?
              (pin dirty 'clipped (copied sc (gaze sc 10) (gaze sc 11)), pier-own s dirty (peep dirty 'clip 0) (u32 raw 4))
              0)
          (pier-keybytes km kc st @ b
             (0 < #b ?
                (0 < gaze sc 8 ? (pier-peer bx dirty (0 - gaze sc 8)) 0,
                 (say m b, flush m))
                0))))

   ; --- the pointer: a press, a release or a move goes to the program when it asked for
   ;     them. unasked, the wheel scrolls the history, or on the alternate screen sends
   ;     three arrows, which a pager or an editor takes as scrolling, and the middle button
   ;     pastes the primary. a move is sent once per cell ---
   pier-xbtn {1 0 2 1 3 2 4 64 5 65 6 66 7 67}         ; X's button -> the report's
   (pier-mods st) ((st & 1 ? 4 0) + (st & 8 ? 8 0) + (st & 4 ? 16 0))
   (pier-held st) (? (st & 256) 0 (st & 512) 1 (st & 1024) 2 3)
   (pier-at raw k d n) (u16 raw k @ v (32767 < v ? 0 (min (n - 1) (v // d))))       ; a signed pixel -> a cell
   (pier-mouse s m bx dirty code raw)
    (: sc (peep bx () 0) st (u16 raw 28)
       row (pier-at raw 26 16 (gaze sc 1)) col (pier-at raw 24 8 (gaze sc 2))
       b (code = 6 ? (pier-held st) (peep pier-xbtn (raw 1) 3))
       at (row * 65536 + col)
       mine ((st & 1 != 0) || !(gaze sc 3 & 7680))       ; unasked, or shift: the button is pier's
       (code = 6 && at = peep dirty 'at -1 ? 0
          (: _ (code = 6 ? (pin dirty 'at at) 0)
             r (mine ? "" (mouse sc (b + pier-mods st) row col (code - 4)))
             (? (0 < #r) (say m r, flush m)
                (code = 4 && 64 <= b <= 65)
                 (gaze sc 3 & 256 ? (say m (cats (map (_ \ (b = 64 ? "\e[A" "\e[B")) (jot 3))), flush m)
                    (pier-peer bx dirty (b = 64 ? 3 -3)))
                (code = 4 && b = 1) (pier-ask s dirty 1 (peep dirty 'utf8 0))
                (mine && (b = 0 || b = 2)) (pier-choose s sc dirty code raw ((row - gaze sc 8) * gaze sc 2 + col) b st)
                0))))

   ; --- the selection: a left press anchors it (a second or third in quick succession on
   ;     the same cell takes the word or the line), a drag stretches it, and a release with
   ;     something chosen takes the primary, the text kept as it was then. a right press, or
   ;     a shift one where no program asked for the mouse, moves the selection's nearer end
   ;     there in its own unit, and the drag goes on from it ---
   (pier-choose s sc dirty code raw gi b st)
    (: t (u32 raw 4) s0 (gaze sc 10) s1 (gaze sc 11)
       stretch (s0 < s1 && (b = 2 || ((st & 1 != 0) && !(gaze sc 3 & 7680))))
       (? (code = 4 && stretch)
          ((? (gi < s0) (s1 - 1) (s1 <= gi) s0 (gi - s0 < s1 - gi) (s1 - 1) s0) @ a
             ((pins dirty 'anchor a 'drag 1),
              select sc a gi (peep dirty 'unit 0),
              pin dirty () 1))
          (code = 4 && b = 0)
          ((t - peep dirty 'tp 0 < 400 && gi = peep dirty 'anchor () ? (min 3 (peep dirty 'clicks 0 + 1)) 1) @ n
             ((pins dirty 'tp t 'anchor gi 'clicks n 'unit (n - 1) 'drag 1),
              select sc gi gi (1 < n ? (n - 1) -1),
              pin dirty () 1))
          !(peep dirty 'drag 0) 0
          (code = 6)
          (select sc (peep dirty 'anchor gi) gi (peep dirty 'unit 0), pin dirty () 1)
          (pin dirty 'drag 0,
           s0 < s1 ?
             (pin dirty 'held (copied sc s0 s1), pier-own s dirty 1 t)
             0)))
   (pier-own s dirty sel t)                             ; SetSelectionOwner: sel is ours
    (pier-hold dirty,
     (x-w8 s 22, x-w8 s 0, x-w16 s 4, x-w32 s (peep dirty 'win 0), x-w32 s sel, x-w32 s t, x-flush s),
     pier-let dirty)
   ; another client asks for the primary or the clipboard: as utf-8 or latin-1 text, or which
   ; targets there are. the answer rides a property of the asker's and a SelectionNotify
   (pier-serve s dirty raw)
    (: rq (u32 raw 12) sel (u32 raw 16) ty (u32 raw 20) pr0 (u32 raw 24)
       tx (? (sel = 1) (dirty 'held) (sel = peep dirty 'clip 0) (dirty 'clipped) ())
       pr (pr0 = 0 ? ty pr0) ut (peep dirty 'utf8 0) tg (peep dirty 'targets 0)
       (prop tp fmt n bs) (#bs @ nb
                            (x-w8 s 18, x-w8 s 0, x-w16 s (6 + (nb + x-pad4 nb) // 4), x-w32 s rq, x-w32 s pr,
                             x-w32 s tp, x-w8 s fmt, x-w8 s 0, x-w16 s 0, x-w32 s n, x-wpad s bs))
       (le4 v) (cats (map (k \ string (v >> 8 * k & 255)) (jot 4)))
       _ (pier-hold dirty)
       ok (? !(string? tx) 0
             (ty = tg) (prop 4 32 3 (le4 tg + le4 ut + le4 31), 1)
             (string? tx && (ty = ut || ty = 31) && #tx < 262000) (prop ty 8 #tx tx, 1)
             0)
       ((x-w8 s 25, x-w8 s 0, x-w16 s 11, x-w32 s rq, x-w32 s 0,
         x-w8 s 31, x-w8 s 0, x-w16 s 0, x-w32 s (u32 raw 4), x-w32 s rq, x-w32 s sel,
         x-w32 s ty, x-w32 s (ok ? pr 0), x-w32 s 0, x-w32 s 0, x-flush s),
        pier-let dirty))
   ; another client took the primary: the highlight goes; the clipboard: its text
   (pier-lost bx dirty raw)
    (? (u32 raw 12 = 1)
       (select (peep bx () 0) 0 0 -1, pin dirty 'held (), pin dirty () 1)
       (u32 raw 12 = peep dirty 'clip 0) (pin dirty 'clipped ())
       0)

   ; --- the socket has two writers, the painter and the watch: a turn runs from a
   ;     request's first byte to its flush ---
   (pier-hold dirty) (0 < peep dirty 'x 0 ? (rest 1, pier-hold dirty) (pin dirty 'x 1))
   (pier-let dirty) (pin dirty 'x 0)

   ; --- paste: the selection is asked for as utf-8 onto a property of ours (latin-1 when
   ;     the owner has no utf-8), and its SelectionNotify says where it landed. it goes to
   ;     the child as `pasted` lays it, and brings the view home as a key does ---
   (pier-ask s dirty sel ty)
    (pier-hold dirty,
     (x-w8 s 24, x-w8 s 0, x-w16 s 6, x-w32 s (peep dirty 'win 0), x-w32 s sel, x-w32 s ty,
      x-w32 s (peep dirty 'prop 0), x-w32 s 0, x-flush s),
     pier-let dirty)
   (pier-send m bx dirty t)
    (peep bx () 0 @ sc
       (0 < gaze sc 8 ? (pier-peer bx dirty (0 - gaze sc 8)) 0,
        (say m (pasted sc t), flush m)))
   ; a paste past what one property carries comes INCR: the owner lays it in pieces on our
   ; property, each after we take the last, and an empty piece ends it
   (pier-take s dirty pr)                               ; GetProperty, deleting: [type format bytes] or ()
    (: _ (pier-hold dirty)
       _ (x-w8 s 20, x-w8 s 1, x-w16 s 6, x-w32 s (peep dirty 'win 0), x-w32 s pr,
          x-w32 s 0, x-w32 s 0, x-w32 s 262144, x-flush s)
       _ (pier-let dirty)
       hdr (x-reply s)
       (? !(<hdr = 1) () [(u32 hdr 8) (hdr 1) (take (u32 hdr 16) (x-rbytes s (4 * u32 hdr 4)))]))
   (pier-text ty bs) (ty = 31 ? (cats (map utf8 bs)) (string bs))
   (pier-got s m bx dirty raw)
    (: sel (u32 raw 12) ty (u32 raw 16) pr (u32 raw 20)
       (pr = 0 ? (ty = peep dirty 'utf8 0 ? (pier-ask s dirty sel 31) 0)
          (pier-take s dirty pr @ v
             (? !(two? v) 0
                (<v = peep dirty 'incr 0) (pins dirty 'pieces () 'incrty ty 'incron 1)
                ((v 1 != 8) || !(two? (v 2))) 0
                (pier-send m bx dirty (pier-text ty (v 2)))))))
   ; PropertyNotify: a new piece on our property while an INCR paste is open
   (pier-piece s m bx dirty raw)
    (u32 raw 4 = peep dirty 'win 0 && u32 raw 8 = peep dirty 'prop 0 && raw 16 = 0 && peep dirty 'incron 0 ?
       (: v (pier-take s dirty (peep dirty 'prop 0))
          bs (two? v ? (v 2))
          (two? bs ? (pin dirty 'pieces (pier-text (peep dirty 'incrty 0) bs . peep dirty 'pieces ()))
             (cats (rev (dirty 'pieces)) @ t
                ((pins dirty 'incron 0 'pieces ()),
                 0 < #t ? (pier-send m bx dirty t) 0))))
       0)

   ; --- the watch: X events in the main task. the moor pumps the child in another and
   ;     seals the socket when the child hangs up, so x-next wakes with () and we leave ---
   (pier-watch s m km dl bx fx dirty)
    (x-next s @ e
       (two? e ?
          (ev-code e @ code
             ((? (code = 2) (pier-key s m km bx dirty (ev-detail e) (ev-state e) (ev-raw e))
                 (4 <= code <= 6) (pier-mouse s m bx dirty code (ev-raw e))
                 (code = 31) (pier-got s m bx dirty (ev-raw e))
                 (code = 30) (pier-serve s dirty (ev-raw e))
                 (code = 29) (pier-lost bx dirty (ev-raw e))
                 (code = 28) (pier-piece s m bx dirty (ev-raw e))
                 (code = 12) (pin dirty () 2)
                 (code = 22) (ev-raw e @ raw (pier-resize bx fx m dirty (u16 raw 20) (u16 raw 22)))
                 0),
              code = 33 && dl = u32 (ev-raw e) 12 ? () (pier-watch s m km dl bx fx dirty)))))

   ; --- pier: argv tied up at the shore, on display socket path, the font () or a laid one.
   ;     answers the child's status pair, or a nom naming what refused ---
   (pier argv path auth font)
    (x-connect path @ s
       (? !(hot? s) 'no-display
          (x-setup s auth @ sc
             (? !(two? sc) (close s, 'refused)
                (: win (scr-idbase sc) gc (scr-idbase sc + 1) depth (scr-depth sc)
                   r 24 c 80
                   _ (pier-mkwin s win (scr-root sc) (c * 8) (r * 16))
                   _ (pier-gc s gc win)
                   _ (pier-title s win "pier")
                   dl (pier-protocols s win)
                   ut (x-intern s "UTF8_STRING") cb (x-intern s "CLIPBOARD") pp (x-intern s "PIER_PASTE")
                   tg (x-intern s "TARGETS") ic (x-intern s "INCR")
                   _ (x-map s win, x-flush s)
                   km (pier-keysyms s (scr-mink sc) (scr-maxk sc))
                   p (hopen argv r c)
                   (? !(two? p) (close s, p)
                      (: bx (hbox p) m (hmas p) pid (hpid p)
                         fx {(cask (c * 8 * (r * 16) * 4))}
                         dirty {1}                   ; the painter's cue at (), and what the tasks share
                         _ (pins dirty 'win win 'utf8 ut 'clip cb 'prop pp 'targets tg 'incr ic)
                         up (twirl (_ \ (moor bx m dirty, seal s 0)) 0)
                         pnt (twirl (_ \ (pier-paints s win gc depth bx fx font dirty -1)) 0)
                         (pier-watch s m km dl bx fx dirty,
                          freeze pnt,
                          landed? up ? (catch up) (still pid 15, freeze up),
                          close s,
                          close m,
                          waitfor pid))))))))

   ; --- the verb ---
   pier-usage "usage: love pier [-f FONT.hex] [-display :N] [CMD ARG..]"
   (pier-main as)
    (: (opt a k d) (? (one? a) d (<a = k && two? >a) <>a (opt >a k d))
       (rest2 a) (? (one? a) () (elem <a ["-f" "-display"]) (rest2 >>a) a)
       disp (opt as "-display" (getenv "DISPLAY"))
       dn (: d (string? disp ? disp "") b (1 < #d ? (snip d 1 #d) "0")
             (: (go i) (i = #b || b i = 46 ? (snip b 0 i) (go (i + 1))) (go 0)))
       fp (opt as "-f" ())
       font (string? fp ? (uread fp @ t (two? t ? (font-hex <>t))))
       argv (rest2 as @ a (two? a ? a [(getenv "SHELL" @ sh (0 < #sh ? sh "sh"))]))
       home (getenv "HOME")
       xa (getenv "XAUTHORITY" @ v (0 < #v ? v (home + "/.Xauthority")))
       st (pier argv ("/tmp/.X11-unix/X" + dn) (xauth-cookie xa dn) font)
       (two? st ? <st (say err ("pier: " + show st + "\n"), 1)))

   door (udoor 'pier pier-main pier-usage 1 1)
   _ (pins (cite 'verbs 'tab) 'pier door)
   s (cite 'verbs 'fire ["pier" "pier.l"])
   _ (two? s ? (quit (door >s)) 0))
) ; module pier
