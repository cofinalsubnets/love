; test/host/luxui-probe.l -- the lux UI probe: a SEPARATE process with its own
; clean X streams (the one-process gate desynced -- see test/host/luxui.l), driven
; by (probe dpy). It creates its own InputOutput toplevels (xterm needs fonts
; a bare Xvfb lacks), drives lux with SYNTHETIC input -- XTEST FakeInput for
; super+drag move/resize, SendEvent ClientMessages for the EWMH requests --
; and asserts every effect off GetGeometry/GetProperty/GetInputFocus:
;   manage -> tile, maximize add/remove (the _NET_WM_STATE stamp both ways),
;   super+btn1 move EXACT, super+btn3 resize EXACT, the float holds the input
;   focus, a second client tiles while the float rides, _NET_CLOSE_WINDOW
;   kills it (no WM_DELETE_WINDOW advertised -> the KillClient fallback).
; Exits 0 iff every assertion held; any failure names itself and exits 1.
; Load order: core -> layout -> wire, then this file; test/host/luxui.l spawns it.
(: (probe dpy)
   (: s (connectu dpy)
      sc (x-setup s ())
      root (scr-root sc)
      (line m) (: _ (say out m) _ (say out "\n") (flush out))
      (fail m) (: _ (line (+ "probe FAIL " m)) (quit 1))
      (must m v) (? v v (fail m))
      ; a patient waiter: poll th every 100ms until it answers true
      (waitp m th t) (? (< t 1) (fail m)
                        (? (th ()) 1 (: _ (rest 100) (waitp m th (- t 1)))))

      ; --- lux is up when ewmh-init has stamped the root ---
      _ (waitp "wm-up" (\ u (two? (x-getprop-atoms s root (x-intern s "_NET_SUPPORTED")))) 100)

      ; --- XTEST: the extension's major opcode, then the super keycode
      ;     (mod4 row of GetModifierMapping, first nonzero) ---
      qx (: n (tally "XTEST")
            _ (x-w8 s 98) _ (x-w8 s 0) _ (x-w16 s (+ 2 (/ (+ n (x-pad4 n)) 4)))
            _ (x-w16 s n) _ (x-w16 s 0) _ (x-wpad s "XTEST") _ (x-flush s)
            hdr (x-reply s) (nthl hdr 9))
      _ (must "xtest-present" (< 0 qx))
      sk (: _ (x-w8 s 119) _ (x-w8 s 0) _ (x-w16 s 1) _ (x-flush s)
            hdr (x-reply s) kpm (nthl hdr 1) data (x-rbytes s (* 8 kpm))
            (go j) (? (< j kpm) (: c (nthl data (+ (* 6 kpm) j)) (? (< 0 c) c (go (+ j 1)))) 0)
            (go 0))
      _ (must "super-keycode" (< 0 sk))
      ; one synthetic input event: xXTestFakeInputReq is 36 bytes (length 9),
      ; rootX/rootY at bytes 24/26; type 2/3 key, 4/5 button, 6 motion (abs)
      (fake ty dt rx ry)
       (: _ (x-w8 s qx) _ (x-w8 s 2) _ (x-w16 s 9) _ (x-w8 s ty) _ (x-w8 s dt) _ (x-w16 s 0)
          _ (x-w32 s 0) _ (x-w32 s 0) _ (x-w32 s 0) _ (x-w32 s 0)
          _ (x-w16 s rx) _ (x-w16 s ry) _ (x-w32 s 0) _ (x-w16 s 0) _ (x-w8 s 0) _ (x-w8 s 0)
          (x-flush s))
      ; an EWMH request: SendEvent (SubstructureRedirect|Notify) to the root
      (cmsg win ty d0 d1 d2)
       (: _ (x-w8 s 25) _ (x-w8 s 0) _ (x-w16 s 11) _ (x-w32 s root) _ (x-w32 s 1572864)
          _ (x-w8 s 33) _ (x-w8 s 32) _ (x-w16 s 0) _ (x-w32 s win) _ (x-w32 s ty)
          _ (x-w32 s d0) _ (x-w32 s d1) _ (x-w32 s d2) _ (x-w32 s 0) _ (x-w32 s 0)
          (x-flush s))
      (getfocus u) (: _ (x-w8 s 43) _ (x-w8 s 0) _ (x-w16 s 1) _ (x-flush s)
                      hdr (x-reply s) (u32 hdr 8))
      ; our own toplevel: InputOutput off the connection's id base, white back
      (mkwin s2 wid rt) (: _ (x-w8 s2 1) _ (x-w8 s2 0) _ (x-w16 s2 9)
                           _ (x-w32 s2 wid) _ (x-w32 s2 rt)
                           _ (x-w16 s2 5) _ (x-w16 s2 5) _ (x-w16 s2 200) _ (x-w16 s2 150)
                           _ (x-w16 s2 1) _ (x-w16 s2 1)
                           _ (x-w32 s2 0)
                           _ (x-w32 s2 2) _ (x-w32 s2 16777215)
                           _ (x-map s2 wid) (x-flush s2))
      a-st (x-intern s "_NET_WM_STATE")
      a-mv (x-intern s "_NET_WM_STATE_MAXIMIZED_VERT")
      a-mh (x-intern s "_NET_WM_STATE_MAXIMIZED_HORZ")
      a-cl (x-intern s "_NET_CLOSE_WINDOW")

      ; --- 1. manage: map -> lux tiles the lone window over the screen ---
      w1 (scr-idbase sc)
      _ (mkwin s w1 root)
      _ (waitp "w1-tiled" (\ u (< 600 (nthl (x-getgeom s w1) 2))) 100)
      _ (waitp "w1-focused" (\ u (= w1 (getfocus ()))) 50)

      ; --- 2. maximize add/remove while TILED (a float's toggle is a no-op
      ;     by design: float-state is the proxy) -- the stamp goes on and off ---
      _ (cmsg w1 a-st 1 a-mv a-mh)
      _ (waitp "maximized" (\ u (: g (x-getgeom s w1)
                                   (&& (= 0 (nthl g 0)) (< 600 (nthl g 2))))) 50)
      _ (waitp "max-stamped" (\ u (= 2 (tally (x-getprop-atoms s w1 a-st)))) 50)
      _ (cmsg w1 a-st 0 a-mv a-mh)
      _ (waitp "unmax-stamped" (\ u (! (x-getprop-atoms s w1 a-st))) 50)

      ; --- 3. super+btn1 drag: float + move, the delta lands EXACT ---
      g0 (x-getgeom s w1)
      cx (+ (nthl g0 0) (// (nthl g0 2) 2)) cy (+ (nthl g0 1) (// (nthl g0 3) 2))
      _ (fake 6 0 cx cy) _ (rest 80)
      _ (fake 2 sk 0 0) _ (rest 80)
      _ (fake 4 1 cx cy) _ (rest 100)
      _ (fake 6 0 (+ cx 40) (+ cy 20)) _ (rest 60)
      _ (fake 6 0 (+ cx 75) (+ cy 45)) _ (rest 100)
      _ (fake 5 1 (+ cx 75) (+ cy 45)) _ (rest 100)
      _ (fake 3 sk 0 0) _ (rest 80)
      _ (waitp "moved-exact" (\ u (: g (x-getgeom s w1)
                                     (&& (= (nthl g 0) (+ (nthl g0 0) 75))
                                         (&& (= (nthl g 1) (+ (nthl g0 1) 45))
                                             (= (nthl g 2) (nthl g0 2)))))) 50)

      ; --- 4. super+btn3 drag: resize, the delta lands EXACT ---
      g1 (x-getgeom s w1)
      rx (+ (nthl g1 0) (// (nthl g1 2) 2)) ry (+ (nthl g1 1) (// (nthl g1 3) 2))
      _ (fake 6 0 rx ry) _ (rest 80)
      _ (fake 2 sk 0 0) _ (rest 80)
      _ (fake 4 3 rx ry) _ (rest 100)
      _ (fake 6 0 (+ rx 50) (+ ry 30)) _ (rest 100)
      _ (fake 5 3 (+ rx 50) (+ ry 30)) _ (rest 100)
      _ (fake 3 sk 0 0) _ (rest 80)
      _ (waitp "resized-exact" (\ u (: g (x-getgeom s w1)
                                       (&& (= (nthl g 2) (+ (nthl g1 2) 50))
                                           (= (nthl g 3) (+ (nthl g1 3) 30))))) 50)
      _ (waitp "float-focused" (\ u (= w1 (getfocus ()))) 50)

      ; --- 5. a second client (its own connection) tiles alongside;
      ;     _NET_CLOSE_WINDOW fells it -- no WM_DELETE_WINDOW advertised, so
      ;     lux takes the KillClient fallback, verified through
      ;     FRESH eyes (the reply stream of a client whose window died
      ;     mid-poll echoes stale replies) ---
      s2 (connectu dpy)
      sc2 (x-setup s2 ())
      w2 (scr-idbase sc2)
      _ (mkwin s2 w2 root)
      _ (waitp "w2-tiled" (\ u (< 300 (nthl (x-getgeom s w2) 2))) 100)           ; w1 floats, so w2 owns the tiling alone
      _ (cmsg w2 a-cl 0 0 0)
      s3 (connectu dpy)
      sc3 (x-setup s3 ())
      _ (waitp "w2-felled" (\ u (! (any (\ k (= k w2)) (x-querytree s3 root)))) 100)

      ; --- 6. LAST, the moor: the live repl evals, survives a scare, CHANGES state
      ;     (msg! 'next-layout flips the ||| index -- read back through the
      ;     SNAPSHOT over the moor socket, so the assert leans on no window
      ;     and no X read), and REFUSES garbage ((lux! 0): (0 st) is 1, not
      ;     a sane 4-list). A queued change drains at lux's next X event; we
      ;     nudge with a no-op ClientMessage from a FRESH connection each time
      ;     (kept open: this Xvfb spuriously CloseDownClient's one client
      ;     ~10s in -- gdb'd to ospoll_wait -> CloseDownClient with the
      ;     victim's socket provably untouched -- so nothing here may lean on
      ;     s staying alive, and closing spares fds would re-arm it) ---
      rsock (: rd (getenv "XDG_RUNTIME_DIR")
               base (? (< 1 (tally rd)) rd "/tmp")
               (+ base (+ "/lux-" (+ (snip dpy 16 (tally dpy)) ".sock"))))
      rc (: (try t) (? (< t 1) ()
                       (: p (connectu rsock)
                          (? (lit? p) p (: _ (rest 100) (try (- t 1))))))
            (try 100))
      _ (must "moor-up" (lit? rc))
      (rdline u) (: (go acc) (: ch (see rc)
                                (? (|| (= ch -1) (= ch 10)) acc (go (+ acc (+ "" ch)))))
                    (go ""))
      (ask q) (: _ (say rc q) _ (say rc "\n") _ (flush rc) (rdline ()))
      _ (must "moor-evals" (= "3" (ask "(+ 1 2)")))
      _ (ask "(boom-unbound)")                                                   ; a scare answers a value; the session lives
      _ (must "moor-survives" (= "7" (ask "(+ 3 4)")))
      (nudge u) (: nf (connectu dpy) sf (x-setup nf ())
                   _ (x-w8 nf 25) _ (x-w8 nf 0) _ (x-w16 nf 11)
                   _ (x-w32 nf root) _ (x-w32 nf 1572864)
                   _ (x-w8 nf 33) _ (x-w8 nf 32) _ (x-w16 nf 0) _ (x-w32 nf root) _ (x-w32 nf 1)
                   _ (x-w32 nf 0) _ (x-w32 nf 0) _ (x-w32 nf 0) _ (x-w32 nf 0) _ (x-w32 nf 0)
                   _ (x-flush nf) (rest 100))
      ; the ||| index rides at minimize>smart>toggle>mirror>choice (config.l's stack)
      chidx "(nthl (nthl (nthl (nthl (nthl (caup (lux-st ())) 2) 1) 2) 2) 1)"
      i0 (ask chidx)
      _ (ask "(msg! 'next-layout)")
      _ (nudge ())
      _ (waitp "moor-changes" (\ u (! (= i0 (ask chidx)))) 50)
      _ (ask "(msg! 'next-layout)")                                              ; flip back (the ||| holds two layouts)
      _ (nudge ())
      _ (waitp "moor-cycles" (\ u (= i0 (ask chidx))) 50)
      _ (ask "(lux! 0)")                                                        ; garbage: refused, the wm stands
      _ (nudge ())
      _ (must "moor-refuses" (= "11" (ask "(+ 5 6)")))
      _ (must "moor-standing" (= i0 (ask chidx)))
      _ (close rc)

      _ (close s3) _ (close s)
      _ (line "probe: manage + maximize + move + resize + focus + moor + close, all exact")
      (quit 0)))
