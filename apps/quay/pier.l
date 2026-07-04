; pier -- berth steps ashore: the terminal emulator in its own X window.
;
; the same moor as berth (a child on a pty, bytes through quay's cb screen),
; but the painter blits the grid into a 32bpp cask framebuffer -- 8x16
; moderndos glyphs, faces and 256 colours, one C blit per cell -- and ships
; it to the server with chunked PutImage over the wm's own wire codec.
; keys come back as KeyPress events, translated keysym -> terminal bytes;
; a ConfigureNotify (the wm retiling us) opens a fresh grid and tells the
; pty; WM_DELETE or the child's exit steps away cleanly. an xterm, ai-native
; from the socket up.
;
; run: out/host/ai -l apps/wm/core.l -l apps/wm/wire.l -l apps/quay/berth.l -l apps/quay/pier.l \
;        -e '(pier (L "sh") "/tmp/.X11-unix/X0" (xauth-cookie "/home/gwen/.Xauthority" "0"))'
;      (auth () suits an -ac or Xvfb server.)
;
; wants: wire.l (the codec), berth.l (moor/waitfor), host/cb.c (screen/blit).
; host-only, never in the corpus; boot/pier.l proves it against a headless
; Xvfb, reading the painted window back with GetImage.

(:
 (px-min a b) (? (< a b) a b)
 (px-upto n f) ((: (go i) (? (< i n) (: _ (f i) (go (+ i 1))) ())) 0)

 ; --- the new requests wire.l never needed: draw ---
 (px-mkwin s win parent x y w h)              ; CreateWindow: InputOutput, black
  (: _ (x-w8 s 1) _ (x-w8 s 0) _ (x-w16 s 10) ; ground, keys+expose+structure
     _ (x-w32 s win) _ (x-w32 s parent)
     _ (x-w16 s x) _ (x-w16 s y) _ (x-w16 s w) _ (x-w16 s h)
     _ (x-w16 s 0) _ (x-w16 s 1) _ (x-w32 s 0)
     _ (x-w32 s 2050)                         ; CWBackPixel | CWEventMask
     _ (x-w32 s 0)
     (x-w32 s 163841))                        ; KeyPress|Exposure|StructureNotify
 (px-gc s gc win)                             ; CreateGC, all defaults
  (: _ (x-w8 s 55) _ (x-w8 s 0) _ (x-w16 s 4) _ (x-w32 s gc) _ (x-w32 s win) (x-w32 s 0))
 (px-title s win t)                           ; ChangeProperty WM_NAME <- STRING
  (: n (tally t)
     _ (x-w8 s 18) _ (x-w8 s 0) _ (x-w16 s (+ 6 (/ (+ n (x-pad4 n)) 4)))
     _ (x-w32 s win) _ (x-w32 s 39) _ (x-w32 s 31) _ (x-w8 s 8)
     _ (x-w8 s 0) _ (x-w16 s 0) _ (x-w32 s n) (x-wpad s t))
 (px-protocols s win)                         ; say we speak WM_DELETE_WINDOW; the atom
  (: prot (x-intern s "WM_PROTOCOLS") del (x-intern s "WM_DELETE_WINDOW")
     _ (x-w8 s 18) _ (x-w8 s 0) _ (x-w16 s 7)
     _ (x-w32 s win) _ (x-w32 s prot) _ (x-w32 s 4) _ (x-w8 s 32)
     _ (x-w8 s 0) _ (x-w16 s 0) _ (x-w32 s 1) _ (x-w32 s del)
     del)

 ; PutImage, chunked: the request length is 16 bits of 4-byte WORDS, so a
 ; band must fit 262112 data bytes NO MATTER THE WIDTH -- a wm retiling us
 ; to a wide monitor makes rows fat, and one over-long request corrupts the
 ; whole stream (the server reads pixels as opcodes: garble, then silence)
 (px-putimg s win gc depth fb wpix hpix)
  (: img (string fb)
     rowb (* wpix 4)
     band (: v (// 262112 rowb) (? (< v 1) 1 (px-min 60 v)))
     (go y) (? (< y hpix)
               (: n (px-min band (- hpix y))
                  bytes (* n rowb)
                  _ (x-w8 s 72) _ (x-w8 s 2) _ (x-w16 s (+ 6 (/ bytes 4)))
                  _ (x-w32 s win) _ (x-w32 s gc)
                  _ (x-w16 s wpix) _ (x-w16 s n)
                  _ (x-w16 s 0) _ (x-w16 s y)
                  _ (x-w8 s 0) _ (x-w8 s depth) _ (x-w16 s 0)
                  _ (say s (snip img (* y rowb) (+ (* y rowb) bytes)))
                  (go (+ y n)))
               (x-flush s))
     (go 0))

 ; --- keyboard: the full keycode -> (sym shifted-sym) table, once ---
 (px-keysyms s mink maxk)
  (: nkc (+ 1 (- maxk mink))
     _ (x-w8 s 101) _ (x-w8 s 0) _ (x-w16 s 2)
     _ (x-w8 s mink) _ (x-w8 s nkc) _ (x-w16 s 0) _ (x-flush s)
     hdr (x-reply s) kpc (nthl hdr 1)
     km (tablet 256)
     _ (px-upto nkc (\ k (: s0 (x-r32 s)
                            s1 (? (< 1 kpc) (x-r32 s) 0)
                            _ (x-skip s (* 4 (? (< 2 kpc) (- kpc 2) 0)))
                            (pin km (+ mink k) (L s0 s1)))))
     km)

 ; a KeyPress -> the bytes a terminal sends. shift picks the second column;
 ; ctrl folds letters onto C0; the specials speak escape; latin-1 goes out
 ; as utf-8 (berth's encoder). anything else is silence.
 (px-keybytes km kc st)
  (: p (peep km kc ())
     (? (! (two? p)) ""
      (: sym (? (&& (& 1 st) (< 0 (caup p))) (caup p) (cap p))
         (? (&& (<= 32 sym) (< sym 127))
            (? (& 4 st) ("" + (& 31 sym)) ("" + sym))
            (&& (<= 160 sym) (< sym 256)) (utf8 sym)
            (= sym 65293) "\r"       (= sym 65288) "\x7f"
            (= sym 65289) "\t"       (= sym 65307) "\e"
            (= sym 65361) "\e[D"     (= sym 65362) "\e[A"
            (= sym 65363) "\e[C"     (= sym 65364) "\e[B"
            (= sym 65360) "\e[H"     (= sym 65367) "\e[F"
            (= sym 65365) "\e[5~"    (= sym 65366) "\e[6~"
            (= sym 65535) "\e[3~"    (= sym 65379) "\e[2~"
            (= sym 65421) "\r"
            ""))))

 ; --- the painter: every cell blits (C does the pixels), the cursor cell
 ; wears reverse, then the frame ships. geometry rides boxes so a resize
 ; swaps grid and framebuffer under us; a torn read just paints one odd
 ; frame (the blit bounds-check keeps it safe) and the next is true.
 (px-paint s win gc depth bx fx)
  (: sc (bx -> 0 0) fb (fx -> 0 0)
     r (gaze sc 1) c (gaze sc 2) w (gaze sc 0) f (gaze sc 3)
     wpix (* c 8) hpix (* r 16)
     _ (px-upto r (\ i (px-upto c (\ q
        (: pos (+ (* i c) q)
           cell (glass sc pos)
           cell2 (? (&& (& 1 f) (= pos w)) (^ cell (<< 4 28)) cell)
           (blit fb wpix cell2 (* q 8) (* i 16)))))))
     (px-putimg s win gc depth fb wpix hpix))

 (px-paintloop s win gc depth bx fx dirty)
  (: _ (? (dirty -> 0 0)
          (: _ (pin dirty 0 0) (px-paint s win gc depth bx fx))
          0)
     _ (rest 33)
     (px-paintloop s win gc depth bx fx dirty))

 ; --- resize: the wm retiled us. a fresh grid and framebuffer to fit,
 ; and the pty learns its new size (SIGWINCH is the kernel's errand) ---
 (px-resize bx fx m dirty wp hp)
  (: r (: v (// hp 16) (? (< 1 v) v 1))
     c (: v (// wp 8) (? (< 1 v) v 2))
     sc (bx -> 0 0)
     (? (&& (= r (gaze sc 1)) (= c (gaze sc 2))) ()
      (: _ (bx <- 0 (screen (cask (screen () r c)) r c))
         _ (fx <- 0 (cask (* (* c 8) (* (* r 16) 4))))
         _ (setwinsize m r c)
         _ (pin dirty 0 1)
         ())))

 ; --- the shore watch: X events in the main task; berth's moor pumps the
 ; child in another and SEALS the socket read when the child hangs up, so
 ; x-next wakes with () and the watch steps away ---
 (px-watch s m km del bx fx dirty)
  (: e (x-next s)
     (? (! (two? e)) ()
      (: code (ev-code e)
         (? (= code 2)
            (: b (px-keybytes km (ev-detail e) (ev-state e))
               _ (? (tally b) (: _ (say m b) (flush m)) 0)
               (px-watch s m km del bx fx dirty))
            (= code 12)
            (: _ (pin dirty 0 1) (px-watch s m km del bx fx dirty))
            (= code 22)
            (: raw (ev-raw e)
               _ (px-resize bx fx m dirty (u16 raw 20) (u16 raw 22))
               (px-watch s m km del bx fx dirty))
            (= code 33)
            (? (= del (u32 (ev-raw e) 12)) () (px-watch s m km del bx fx dirty))
            (px-watch s m km del bx fx dirty)))))

 ; --- pier: tie argv up at the shore. returns the child's status pair,
 ; or a nom naming what refused ---
 (pier argv dpy auth)
  (: s (x-connect dpy)
     (? (! (lit? s)) 'no-socket
      (: sc (x-setup s auth)
         (? (! (two? sc)) (: _ (close s) 'refused)
          (: win (scr-idbase sc) gc (+ 1 (scr-idbase sc))
             depth (scr-depth sc)
             r 24 c 80
             _ (px-mkwin s win (scr-root sc) 0 0 (* c 8) (* r 16))
             _ (px-gc s gc win)
             _ (px-title s win "berth")
             del (px-protocols s win)
             _ (x-map s win)
             _ (x-flush s)
             km (px-keysyms s (scr-mink sc) (scr-maxk sc))
             md (mind argv)
             (? (! (two? md)) (: _ (close s) md)
              (: pid (cap md) m (cup md)
                 s0 (screen (cask (screen () r c)) r c)
                 bx #s0
                 f0 (cask (* (* c 8) (* (* r 16) 4)))
                 fx #f0
                 dirty #1
                 _ (setwinsize m r c)
                 up (spin (\ _ (: _ (moor bx m dirty) (seal s 0))) 0)
                 pnt (spin (\ _ (px-paintloop s win gc depth bx fx dirty)) 0)
                 _ (px-watch s m km del bx fx dirty)
                 _ (freeze pnt)
                 _ (? (back? up) (catch up) (: _ (still pid 15) (freeze up)))
                 _ (close s)
                 _ (close m)
                 (waitfor pid)))))))))
