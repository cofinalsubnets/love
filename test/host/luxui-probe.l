; test/host/luxui-probe.l -- the lux ui probe, spawned by test/host/luxui.l as its own process
; with clean X streams. it makes its own toplevels, drives lux with synthetic input (xtest for
; super+drag, SendEvent for the EWMH requests) and asserts every effect off the server's answers:
; tiling, maximize, move/resize, close, withdraw and re-show, the unmap ledger, focus hand-off,
; activation, and a sunk float landing in the slot it left. exits 0 iff every assertion held.
; loaded with -l after core, layout and wire, no test/00-init.l ahead: posix is borrowed here.
(cite 'posix ? (borrow 'posix) ())

(borrow 'xwire)   ; the X wire, src/apps/lux/wire.l
(: (probe dpy)
   (: s (connect ['unix dpy])
      sc (x-setup s ())
      root (scr-root sc)
      (line m) (say out m, say out "\n", flush out)
      (fail m) (line ("probe FAIL " + m), quit 1)
      (must m v) (v ? v (fail m))
      ; a patient waiter: poll th every 100ms until it answers true
      (waitp m th t) (t < 1 ? (fail m) (th () ? 1 (rest 100, waitp m th (t - 1))))

      ; --- lux is up when ewmh-init has stamped the root ---
      _ (waitp "wm-up" (u \ two? (x-getprop-atoms s root (x-intern s "_NET_SUPPORTED"))) 100)
      ; --- the wm's name ---
      sup (x-getprop-atoms s root (x-intern s "_NET_SUPPORTING_WM_CHECK") @ c (two? c ? <c 0))
      _ (must "wm-name" (x-getprop s sup (x-intern s "_NET_WM_NAME") @ [8 n b]
                          (foldl (a \ c \ a + string c) "" b @ nm
                             (snip nm 0 11 = "lux / love " && n > 11))))
      ; --- the desktop's shape (ewmh 1.4): geometry is the root, a viewport and a workarea row
      ;     per desktop, and the names are the tags as NUL-terminated strings ---
      nd (x-getprop-atoms s root (x-intern s "_NET_NUMBER_OF_DESKTOPS") @ d (two? d ? <d 0))
      _ (must "desktops-published" (0 < nd))
      _ (waitp "desktop-geometry" (u \ '(640 480) = x-getprop-atoms s root (x-intern s "_NET_DESKTOP_GEOMETRY")) 50)   ; sync's, a beat after init
      _ (must "desktop-viewport" (2 * nd = #(x-getprop-atoms s root (x-intern s "_NET_DESKTOP_VIEWPORT"))))
      _ (waitp "workarea" (u \ (x-getprop-atoms s root (x-intern s "_NET_WORKAREA") @ w
                                  (4 * nd = #w && '(0 0 640 480) = take 4 w))) 50)
      _ (must "desktop-names" (x-getprop s root (x-intern s "_NET_DESKTOP_NAMES") @ [8 n b]      ; format 8, one digit + NUL per desktop
                                (2 * nd = n && 2 * nd = #b && 0 = b (n - 1))))

      ; --- xtest: the extension's major opcode, then the super keycode
      ;     (mod4 row of GetModifierMapping, first nonzero) ---
      qx (: n #"XTEST"
            _ (x-w8 s 98, x-w8 s 0, x-w16 s (2 + (n + x-pad4 n) / 4),
               x-w16 s n, x-w16 s 0, x-wpad s "XTEST", x-flush s)
            hdr (x-reply s) (hdr 9))
      _ (must "xtest-present" (0 < qx))
      sk (: _ (x-w8 s 119, x-w8 s 0, x-w16 s 1, x-flush s)
            hdr (x-reply s) kpm (hdr 1) data (x-rbytes s (8 * kpm))
            (go j) (j < kpm ? (data (6 * kpm + j) @ c (0 < c ? c (go (j + 1)))) 0)
            (go 0))
      _ (must "super-keycode" (0 < sk))
      ; one synthetic input event: xxtestFakeInputReq is 36 bytes (length 9),
      ; rootX/rootY at bytes 24/26; type 2/3 key, 4/5 button, 6 motion (abs)
      (fake ty dt rx ry)
       (x-w8 s qx, x-w8 s 2, x-w16 s 9, x-w8 s ty, x-w8 s dt, x-w16 s 0,
        x-w32 s 0, x-w32 s 0, x-w32 s 0, x-w32 s 0,
        x-w16 s rx, x-w16 s ry, x-w32 s 0, x-w16 s 0, x-w8 s 0, x-w8 s 0,
        x-flush s)
      ; an EWMH request: SendEvent (SubstructureRedirect|Notify) to the root
      (cmsg win ty d0 d1 d2)
       (x-w8 s 25, x-w8 s 0, x-w16 s 11, x-w32 s root, x-w32 s 1572864,
        x-w8 s 33, x-w8 s 32, x-w16 s 0, x-w32 s win, x-w32 s ty,
        x-w32 s d0, x-w32 s d1, x-w32 s d2, x-w32 s 0, x-w32 s 0,
        x-flush s)
      (getfocus u) (: _ (x-w8 s 43, x-w8 s 0, x-w16 s 1, x-flush s)
                      hdr (x-reply s) (u32 hdr 8))
      ; a window's parent (QueryTree), and its geometry as the screen sees it: lux
      ; frames what it manages, so that is the frame's rect, else the window's own
      (parent w) (: _ (x-w8 s 15, x-w8 s 0, x-w16 s 2, x-w32 s w, x-flush s)
                    hdr (x-reply s) _ (<hdr = 1 ? (x-rbytes s (u32 hdr 4 * 4)) 0)
                    (<hdr = 1 ? (u32 hdr 12) 0))
      ; a framed client reads (0 0) off its own geometry: rgeo is the frame's, which the screen sees
      (top w) (parent w @ p (p = root || p = 0 ? w p))                       ; the root's child that holds w
      (rgeo w) (x-getgeom s (top w))
      ; our own toplevel: InputOutput off the connection's id base, white back
      (mkwin s2 wid rt) (x-w8 s2 1, x-w8 s2 0, x-w16 s2 9,
                           x-w32 s2 wid, x-w32 s2 rt,
                           x-w16 s2 5, x-w16 s2 5, x-w16 s2 200, x-w16 s2 150,
                           x-w16 s2 1, x-w16 s2 1,
                           x-w32 s2 0,
                           x-w32 s2 2, x-w32 s2 16777215,
                           x-map s2 wid, x-flush s2)
      a-st (x-intern s "_NET_WM_STATE")
      a-mv (x-intern s "_NET_WM_STATE_MAXIMIZED_VERT")
      a-mh (x-intern s "_NET_WM_STATE_MAXIMIZED_HORZ")
      a-cl (x-intern s "_NET_CLOSE_WINDOW")

      ; --- 1. manage: map -> lux tiles the lone window over the screen ---
      w1 (scr-idbase sc)
      _ (mkwin s w1 root)
      _ (waitp "w1-tiled" (u \ 600 < rgeo w1 2) 100)
      ; --- 1b. framed: w1 rides in a frame of its own size at (0 0), no extents ---
      _ (must "framed" (parent w1 @ p (p != root && p != 0)))
      _ (must "framed-at-origin" (x-getgeom s w1 @ g (rgeo w1 @ fg (<g = 0 && <>g = 0 && g 2 = fg 2 && g 3 = fg 3))))
      _ (must "frame-extents" ('(0 0 0 0) = x-getprop-atoms s w1 (x-intern s "_NET_FRAME_EXTENTS")))
      _ (waitp "w1-focused" (u \ w1 = getfocus ()) 50)

      ; --- 2. maximize add/remove while tiled -- the stamp goes on and off ---
      _ (cmsg w1 a-st 1 a-mv a-mh)
      _ (waitp "maximized" (u \ rgeo w1 @ g
                                   (0 = g 0 && 600 < g 2)) 50)
      _ (waitp "max-stamped" (u \ 2 = #(x-getprop-atoms s w1 a-st)) 50)
      _ (cmsg w1 a-st 0 a-mv a-mh)
      _ (waitp "unmax-stamped" (u \ !(x-getprop-atoms s w1 a-st)) 50)

      ; --- 3. super+btn1 drag: float + move, the delta lands exact ---
      g0 (rgeo w1) c0 (x-getgeom s w1)
      cx (g0 0 + g0 2 // 2) cy (g0 1 + g0 3 // 2)
      _ (fake 6 0 cx cy, rest 80,
         fake 2 sk 0 0, rest 80,
         fake 4 1 cx cy, rest 100,
         fake 6 0 (cx + 40) (cy + 20), rest 60,
         fake 6 0 (cx + 75) (cy + 45), rest 100,
         fake 5 1 (cx + 75) (cy + 45), rest 100,
         fake 3 sk 0 0, rest 80)
      _ (waitp "moved-exact" (u \ (rgeo w1 @ g
                                     (g 0 = g0 0 + 75 && g 1 = g0 1 + 45 && x-getgeom s w1 2 = c0 2))) 50)   ; the client keeps its size; its frame gains the border

      ; --- 4. super+btn3 drag: resize, the delta lands exact ---
      g1 (rgeo w1)
      rx (g1 0 + g1 2 // 2) ry (g1 1 + g1 3 // 2)
      _ (fake 6 0 rx ry, rest 80,
         fake 2 sk 0 0, rest 80,
         fake 4 3 rx ry, rest 100,
         fake 6 0 (rx + 50) (ry + 30), rest 100,
         fake 5 3 (rx + 50) (ry + 30), rest 100,
         fake 3 sk 0 0, rest 80)
      _ (waitp "resized-exact" (u \ (rgeo w1 @ g
                                     (g 2 = g1 2 + 50 && g 3 = g1 3 + 30))) 50)
      _ (waitp "float-focused" (u \ w1 = getfocus ()) 50)
      ; --- 4b. a remove of a state lux never stamped leaves the float alone ---
      g2 (rgeo w1)
      _ (cmsg w1 a-st 0 a-mv a-mh, rest 150)
      _ (must "unmax-unstamped-float-kept" (rgeo w1 = g2))

      ; --- 5. a second client (its own connection) tiles alongside;
      ;     _net_close_window fells it -- no wm_delete_window advertised, so
      ;     lux takes the KillClient fallback, verified through
      ;     fresh eyes (the reply stream of a client whose window died
      ;     mid-poll echoes stale replies) ---
      s2 (connect ['unix dpy])
      sc2 (x-setup s2 ())
      w2 (scr-idbase sc2)
      _ (mkwin s2 w2 root)
      _ (waitp "w2-tiled" (u \ 300 < rgeo w2 2) 100)           ; w1 floats, so w2 owns the tiling alone
      _ (cmsg w2 a-cl 0 0 0)
      s3 (connect ['unix dpy])
      sc3 (x-setup s3 ())
      _ (waitp "w2-felled" (u \ x-querytree s3 root @ t                       ; a failed query is not
                                 (two? t && !(any (= w2) <>t))) 100)   ; "felled"

      ; --- 5b. the withdraw race (the telegram media-viewer zombie): a client
      ;     hides a fullscreen float Qt-style -- a real unmap, then the ICCCM
      ;     synthetic UnmapNotify. The real unmap's pointer crossing renders
      ;     while the float is still in the sheaf, so the render re-maps it;
      ;     the withdraw must leave the window unmapped anyway, and a re-show
      ;     must arrive as a fresh MapRequest and re-manage fullscreen. ---
      a-fs (x-intern s "_NET_WM_STATE_FULLSCREEN")
      wt (w1 + 1)                                                                ; a tile under the pointer: a crossing focuses whatever
      _ (mkwin s wt root)                                                        ; it lands on, tile or float, by the same path
      _ (waitp "wt-tiled" (u \ 600 < rgeo wt 2) 100)
      wv (w1 + 2)
      _ (x-w8 s 1, x-w8 s 0, x-w16 s 9,                               ; create (unmapped): white 300x200 toplevel
         x-w32 s wv, x-w32 s root,
         x-w16 s 0, x-w16 s 0, x-w16 s 300, x-w16 s 200,
         x-w16 s 1, x-w16 s 1, x-w32 s 0,
         x-w32 s 2, x-w32 s 16777215, x-flush s)
      _ (x-w8 s 18, x-w8 s 0, x-w16 s 7, x-w32 s wv,               ; _net_wm_state = [fullscreen] before the map (Qt showFullScreen)
         x-w32 s a-st, x-w32 s 4, x-w8 s 32, x-w8 s 0,
         x-w16 s 0, x-w32 s 1, x-w32 s a-fs, x-flush s)
      (mapv u) (x-w8 s 8, x-w8 s 0, x-w16 s 2, x-w32 s wv, x-flush s)
      (mstv u) <(x-attrs s wv)                                              ; 2 = viewable, 0 = unmapped
      _ (fake 6 0 30 20, rest 80)                                                ; park the pointer over the bare tile (the w1 float, dragged
                                                                                 ; off its near-fullscreen tiled rect, leaves only this strip):
                                                                                 ; the withdraw's crossing must land in the tile to render
      _ (mapv ())
      _ (waitp "wv-fullscreen" (u \ 600 < rgeo wv 2) 50)
      (withdraw u) (x-unmap s wv,                                           ; the real unmap, then the courtesy synthetic to the root
                    x-w8 s 25, x-w8 s 0, x-w16 s 11, x-w32 s root, x-w32 s 1572864,
                    x-w8 s 18, x-w8 s 0, x-w16 s 0, x-w32 s root, x-w32 s wv,
                    x-w32 s 0, x-w32 s 0, x-w32 s 0, x-w32 s 0, x-w32 s 0,
                    x-flush s)
      _ (withdraw ())
      _ (waitp "wv-withdraw-unstamped" (u \ atom? (x-getprop-atoms s wv (x-intern s "WM_STATE"))) 50)
      _ (rest 300)                                                               ; let any resurrecting render land before the read
      _ (waitp "wv-withdraw-unmapped" (u \ 0 = mstv ()) 50)
      _ (must "wv-unframed" (parent wv = root))                                    ; withdrawn: back on the root, its frame gone
      _ (mapv ())
      _ (waitp "wv-reshow-fullscreen" (u \ 2 = mstv () && 600 < rgeo wv 2 && two? (x-getprop-atoms s wv (x-intern s "WM_STATE"))) 50)
      _ (withdraw ())                                                            ; leave it withdrawn: the moor leg leans on nothing here
      _ (waitp "wv-rewithdraw" (u \ = 0 (mstv ())) 50)

      ; --- 5c. the unmap ledger (xmonad's waitingUnmap): lux's own hides --
      ;     workspace switch, minimize -- echo back counted and must not evict;
      ;     a rude client unmap (no ICCCM courtesy synthetic at all) must ---
      a-cd (x-intern s "_NET_CURRENT_DESKTOP")
      a-aw (x-intern s "_NET_ACTIVE_WINDOW")
      a-ic (x-intern s "WM_CHANGE_STATE")
      a-li (x-intern s "_NET_CLIENT_LIST")
      wr (w1 + 3)
      _ (x-w8 s 1, x-w8 s 0, x-w16 s 9,                                          ; a plain tile
           x-w32 s wr, x-w32 s root,
           x-w16 s 0, x-w16 s 0, x-w16 s 300, x-w16 s 200,
           x-w16 s 1, x-w16 s 1, x-w32 s 0,
           x-w32 s 2, x-w32 s 16777215, x-flush s)
      (mapr u) (x-w8 s 8, x-w8 s 0, x-w16 s 2, x-w32 s wr, x-flush s)
      (mstr u) <(x-attrs s wr)
      (known? u) (any (= wr) (x-getprop-atoms s root a-li))
      _ (mapr ())
      _ (waitp "wr-tiled" (u \ known? ()) 50)
      _ (cmsg root a-cd 1 0 0)                                                   ; our hide: the switch away...
      _ (waitp "wr-switch-hidden" (u \ 0 = mstr ()) 50)
      _ (must "wr-switch-keeps" (known? ()))                                     ; ...counted, not a withdraw
      _ (cmsg root a-cd 0 0 0)
      _ (waitp "wr-switch-back" (u \ 2 = mstr ()) 50)
      _ (cmsg wr a-ic 3 0 0)                                                     ; our hide: iconify (the layout drops it)...
      _ (waitp "wr-minimized" (u \ 0 = mstr ()) 50)
      _ (must "wr-minimize-keeps" (known? ()))                                   ; ...counted too
      _ (cmsg wr a-aw 0 0 0)                                                     ; a pager activates: restore
      _ (waitp "wr-restored" (u \ 2 = mstr ()) 50)
      _ (x-unmap s wr, x-flush s)                                                ; the rude hide: a raw client unmap, no synthetic --
      _ (waitp "wr-rude-evicts" (u \ !(known? ())) 50)                        ; an unowed real unmap is the withdraw
      _ (waitp "wr-rude-unstamped" (u \ ! (two? (x-getprop-atoms s wr (x-intern s "WM_STATE")))) 50)
      _ (rest 300)                                                               ; let any resurrecting render land before the read
      _ (must "wr-rude-unmapped" (0 = mstr ()))
      _ (mapr ())                                                                ; and the re-show re-manages
      _ (waitp "wr-remanaged" (u \ known? () && 2 = mstr ()) 50)

      ; --- 5d. close the focused tile: a survivor must take the keyboard.
      ;     the pointer parks over the float first, so no crossing can hand
      ;     focus on -- only lux's own refocus after the eviction can. which
      ;     survivor is the ring's business (zdel falls down, then up, over
      ;     every window on the view, float or tile), so the assert is that
      ;     the keyboard lands on a live client and not on the corpse, the
      ;     root, or PointerRoot ---
      gf (rgeo w1)
      _ (fake 6 0 (gf 0 + gf 2 // 2) (gf 1 + gf 3 // 2), rest 100)
      _ (cmsg wt a-aw 0 0 0)                                                     ; activate the victim: two tiles, wt holds the focus
      _ (waitp "victim-focused" (u \ = wt (getfocus ())) 50)
      _ (x-w8 s 4, x-w8 s 0, x-w16 s 2, x-w32 s wt, x-flush s)   ; DestroyWindow: the app quits
      _ (waitp "survivor-focused"
            (u \ getfocus () @ f (f != wt && f != 1 && f != root && 0 < f)) 50)

      ; --- 5e. the activation source (ewmh 1.4 _net_active_window data[0]): a
      ;     pager (2) or a legacy client (0) may pull the view to its window,
      ;     the app asking for itself (1) may not -- a qt modal re-asserts its
      ;     own activation on every focus change, and an obeyed request would
      ;     undo the switch that just left it ---
      (deskt u) (x-getprop-atoms s root a-cd @ d (two? d ? <d -1))
      _ (cmsg root a-cd 1 0 0)                                                   ; the pager switches off wr's desktop
      _ (waitp "aw-switched-away" (u \ 1 = deskt () && 0 = mstr ()) 50)
      _ (cmsg wr a-aw 1 0 0)                                                     ; the app asks for itself: refused
      _ (rest 300)                                                               ; let an obeyed request land before the read
      _ (must "aw-app-holds-view" (1 = deskt ()))
      _ (must "aw-app-holds-hidden" (0 = mstr ()))
      _ (cmsg wr a-aw 2 0 0)                                                     ; the pager asks: honoured
      _ (waitp "aw-pager-switches" (u \ 0 = deskt () && 2 = mstr ()) 50)

      ; --- 5f. the view change must land the keyboard. switch renders but does
      ;     not focus, and wsfoc reads the tiled zipper -- so a view holding a
      ;     float alone used to arrive with the focus at PointerRoot, the float
      ;     visible and wearing the focused border with no keyboard. an empty
      ;     view takes the root, so a raw-mapped dock under the pointer cannot
      ;     collect the keys. the pointer parks off the float throughout: a
      ;     crossing would hand the focus on and hide the whole thing ---
      a-wt (x-intern s "_NET_WM_WINDOW_TYPE")
      a-dl (x-intern s "_NET_WM_WINDOW_TYPE_DIALOG")
      a-wd (x-intern s "_NET_WM_DESKTOP")
      wf (w1 + 5) wg (w1 + 6)
      (mkdlg wid)                                                                ; a dialog: the manage hook floats it at its own size
       (x-w8 s 1, x-w8 s 0, x-w16 s 9, x-w32 s wid, x-w32 s root,
             x-w16 s 5, x-w16 s 5, x-w16 s 200, x-w16 s 150,
             x-w16 s 1, x-w16 s 1, x-w32 s 0, x-w32 s 2, x-w32 s 16777215,
        x-w8 s 18, x-w8 s 0, x-w16 s 7, x-w32 s wid,                         ; ChangeProperty: the type, before the map
             x-w32 s a-wt, x-w32 s 4, x-w8 s 32, x-w8 s 0, x-w16 s 0,
             x-w32 s 1, x-w32 s a-dl,
        x-map s wid, x-flush s)
      (mstf u) <(x-attrs s wf)
      (actw u) (x-getprop-atoms s root a-aw @ a (two? a ? <a -1))          ; _net_active_window: what a taskbar highlights
      _ (mkdlg wf)
      _ (waitp "wf-floated" (u \ 200 = x-getgeom s wf 2) 100)          ; a float keeps its own size; a tile would be stretched
      _ (cmsg wf a-wd 1 0 0)                                                     ; send it to desktop 1, alone there
      _ (waitp "wf-emigrated" (u \ 0 = mstf ()) 50)
      _ (fake 6 0 5 5, rest 100)                                                 ; park the pointer off the centred float
      _ (cmsg root a-cd 1 0 0)                                                   ; arrive at a view of one float and no tile
      _ (waitp "wf-shown" (u \ 2 = mstf ()) 50)
      _ (waitp "wf-holds-keyboard" (u \ wf = getfocus ()) 50)
      _ (must "wf-advertised" (wf = actw ()))                                  ; and the model agrees: wsfoc cannot name a float, so
                                                                                 ; _net_active_window read 0 while one held the keyboard
      ; a second float takes the keyboard; destroying it must hand both the
      ; keyboard and the advertisement back, not just the keyboard
      _ (mkdlg wg)
      _ (waitp "wg-holds-keyboard" (u \ wg = getfocus () && wg = actw ()) 100)
      _ (x-w8 s 4, x-w8 s 0, x-w16 s 2, x-w32 s wg, x-flush s)   ; DestroyWindow
      _ (waitp "wf-regains" (u \ wf = getfocus () && wf = actw ()) 50)
      _ (cmsg root a-cd 2 0 0)                                                   ; and an empty view: the root, never PointerRoot (1)
      _ (waitp "empty-view-roots" (u \ root = getfocus ()) 50)
      _ (cmsg root a-cd 0 0 0)                                                   ; back where leg 6 expects to find us
      _ (waitp "back-to-first" (u \ 0 = deskt () && 2 = mstr ()) 50)

      ; --- 6. last, the moor: the live repl evals, survives a scare, changes state
      ;     (msg! 'next-layout flips the ||| index -- read back through the
      ;     snapshot over the moor socket, so the assert leans on no window
      ;     and no X read), and refuses garbage ((lux! 0): (0 st) is 1, not
      ;     a sane 3-list). a queued change drains at lux's next X event; we
      ;     nudge with a no-op ClientMessage from a fresh connection each time
      ;     (kept open: this Xvfb spuriously CloseDownClient's one client
      ;     ~10s in -- gdb'd to ospoll_wait -> CloseDownClient with the
      ;     victim's socket provably untouched -- so nothing here may lean on
      ;     s staying alive, and closing spares fds would re-arm it) ---
      rsock (: rd (getenv "XDG_RUNTIME_DIR")
               base (1 < #rd ? rd "/tmp")
             (base + "/lux-" + snip dpy 16 #dpy + ".sock"))
      rc (: (try t) (t >= 1 ? (connect ['unix rsock] @ p
                          (lit? p ? p (rest 100, try (t - 1)))))
            (try 100))
      _ (must "moor-up" (lit? rc))
      (rdline u) (: (go acc) (see rc @ (-1 || 10) acc ch (go (acc + string ch))) (go ""))
      (ask q) (say rc q, say rc "\n", flush rc, rdline ())
      _ (must "moor-evals" ("3" = ask "(+ 1 2)"))
      _ (ask "(boom-unbound)")                                                   ; a scare answers a value; the session lives
      _ (must "moor-survives" ("7" = ask "(+ 3 4)"))
      (nudge u) (: nf (connect ['unix dpy]) sf (x-setup nf ())
                 (x-w8 nf 25, x-w8 nf 0, x-w16 nf 11,
                  x-w32 nf root, x-w32 nf 1572864,
                  x-w8 nf 33, x-w8 nf 32, x-w16 nf 0, x-w32 nf root, x-w32 nf 1,
                  x-w32 nf 0, x-w32 nf 0, x-w32 nf 0, x-w32 nf 0, x-w32 nf 0,
                  x-flush nf, rest 100))
      ; the ||| index rides at minimize>smart>toggle>mirror>choice (config.l's stack);
      ; (lay ()) is the current tag's layout out of the book
      chidx "((((((lay ()) 2) 1) 2) 2) 1)"
      i0 (ask chidx)
      _ (ask "(msg! 'next-layout)")
      _ (nudge ())
      _ (waitp "moor-changes" (u \ i0 != ask chidx) 50)
      _ (ask "(msg! 'next-layout)")                                              ; flip back (the ||| holds two layouts)
      _ (nudge ())
      _ (waitp "moor-cycles" (u \ i0 = ask chidx) 50)
      _ (ask "(lux! 0)")                                                        ; garbage: refused, the wm stands
      _ (nudge ())
      _ (must "moor-refuses" ("11" = ask "(+ 5 6)"))
      _ (must "moor-standing" (i0 = ask chidx))

      ; --- 6b. the book: a layout is the tag's own. flip on tag 1, view tag 2 --
      ;     it still reads the configured stack -- and tag 1 kept its flip ---
      _ (ask "(msg! 'next-layout)")
      _ (nudge ())
      _ (waitp "book-flips" (u \ i0 != ask chidx) 50)
      _ (cmsg root a-cd 1 0 0)
      _ (waitp "book-other-tag" (u \ 1 = deskt () && i0 = ask chidx) 50)
      _ (cmsg root a-cd 0 0 0)
      _ (waitp "book-kept" (u \ 0 = deskt () && i0 != ask chidx) 50)
      _ (ask "(msg! 'next-layout)")                                              ; flip back: leg 7 starts from i0
      _ (nudge ())
      _ (waitp "book-restored" (u \ = i0 (ask chidx)) 50)

      ; --- 6c. the screens: randr 1.5 monitors are lux's screens. two client
      ;     monitors (this connection's, so they live while it does), then mod+n
      ;     (refresh) -- the server sends no event for a client monitor, and a
      ;     SendEvent of an extension code is not delivered -- and lux re-reads
      ;     the monitors: every tag lands on a screen; deleted, it folds back to one ---
      rr (x-randr-init s root)
      _ (must "randr-1.5" (two? rr))
      out0 (: _ (x-w8 s <rr, x-w8 s 42, x-w16 s 3, x-w32 s root, x-w8 s 1, x-w8 s 0, x-w16 s 0, x-flush s)   ; RRGetMonitors: the auto
              hdr (x-reply s) b (x-rbytes s (4 * u32 hdr 4))                     ; monitor's one output -- a client monitor claiming it
              (0 < u16 b 6 ? (u32 b 24) 0))                                       ; retires the auto one, which would swallow ours (a clone is no screen)
      _ (must "auto-output" (0 < out0))
      (setmon nm x w outs) (x-intern s nm @ a                                  ; RRSetMonitor: name, not primary, not automatic, its outputs
                              (x-w8 s <rr, x-w8 s 43, x-w16 s (8 + #outs), x-w32 s root, x-w32 s a, x-w8 s 0, x-w8 s 0, x-w16 s #outs,
                               x-w16 s x, x-w16 s 0, x-w16 s w, x-w16 s 480, x-w32 s 100, x-w32 s 100,
                               map (x-w32 s) outs, x-flush s))
      (delmon nm) (x-intern s nm @ a                                          ; RRDeleteMonitor (the atom first: a round trip mid-request garbles the stream)
                     (x-w8 s <rr, x-w8 s 44, x-w16 s 3, x-w32 s root, x-w32 s a, x-flush s))
      nk (peep (x-keymap s (scr-mink sc) (scr-maxk sc) [110]) 110 0)             ; n: mod+n is refresh
      _ (must "n-keycode" (0 < nk))
      (refresh u) (fake 2 sk 0 0, rest 60, fake 2 nk 0 0, rest 60,
                   fake 3 nk 0 0, rest 60, fake 3 sk 0 0, rest 100)
      (nscreens u) (ask "(tally (wsvis (cap (lux-st ()))))")
      _ (must "one-screen" ("1" = nscreens ()))
      _ (setmon "left" 0 213 [out0], setmon "mid" 213 213 (), setmon "right" 426 214 ())
      _ (refresh ())
      _ (waitp "screens-found" (u \ "3" = nscreens ()) 50)                       ; left, mid, right; the auto monitor retired with its output
      _ (must "screen-rect" ("(0 0 213 480)" = ask "(wsrectof (cap (lux-st ())) 1)"))
      _ (must "screens-tags" ("(1 2 3)" = ask "(wsvistags (cap (lux-st ())))"))

      ; --- 6d. per-screen rendering: a fresh window on tag 1 tiles into the left
      ;     screen; viewing tag 2 (on the middle screen) is greedy -- the tags trade
      ;     screens, so the window lands in the middle rect; back again, the left ---
      w6 (w1 + 9)
      _ (mkwin s w6 root)
      _ (waitp "screen-tiled" (u \ (rgeo w6 @ g (g 0 + g 2 <= 213 && 50 < g 2))) 50)
      _ (fake 6 0 5 475, rest 80)                                                ; the pointer to the left screen: a crossing makes its screen current
      _ (cmsg root a-cd 1 0 0)
      _ (waitp "screen-traded" (u \ (rgeo w6 @ g (213 <= g 0 && g 0 + g 2 <= 426))) 50)
      _ (waitp "screen-cur" (u \ "2" = ask "(wscur (cap (lux-st ())))") 50)              ; the crossing lands when it lands
      _ (waitp "screen-vis" (u \ "(2 1 3)" = ask "(wsvistags (cap (lux-st ())))") 50)
      _ (cmsg root a-cd 0 0 0)
      _ (waitp "screen-back" (u \ (rgeo w6 @ g (g 0 + g 2 <= 213))) 50)
      _ (waitp "screen-vis-back" (u \ "(1 2 3)" = ask "(wsvistags (cap (lux-st ())))") 50)

      ; --- 6d2. a dock's strut reaches only the screens its span meets, and follows the
      ;     dock when it rewrites the strut in place (a panel changing outputs never
      ;     remaps): a top-40 strut over the left screen, then moved to the right one ---
      wd (w1 + 20)
      (prop32 w a ty vals) (x-w8 s 18, x-w8 s 0, x-w16 s (6 + #vals), x-w32 s w, x-w32 s a,   ; ChangeProperty Replace, format 32
                            x-w32 s ty, x-w8 s 32, x-w8 s 0, x-w16 s 0, x-w32 s #vals,
                            map (x-w32 s) vals, x-flush s)
      a-sp (x-intern s "_NET_WM_STRUT_PARTIAL")
      _ (x-w8 s 1, x-w8 s 0, x-w16 s 8, x-w32 s wd, x-w32 s root,                        ; CreateWindow 213x40 at the top, no values
         x-w16 s 0, x-w16 s 0, x-w16 s 213, x-w16 s 40, x-w16 s 0, x-w16 s 1, x-w32 s 0, x-w32 s 0, x-flush s)
      _ (prop32 wd (x-intern s "_NET_WM_WINDOW_TYPE") 4 [(x-intern s "_NET_WM_WINDOW_TYPE_DOCK")])
      _ (prop32 wd a-sp 6 '(0 0 40 0 0 0 0 0 0 212 0 0))
      _ (x-map s wd, x-flush s)
      _ (waitp "strut-left" (u \ (rgeo w6 @ g (40 <= g 1 && g 1 + g 3 <= 480))) 50)
      _ (prop32 wd a-sp 6 '(0 0 40 0 0 0 0 0 426 639 0 0))
      _ (waitp "strut-moved" (u \ (rgeo w6 @ g (g 1 < 40 && 440 < g 3))) 50)
      _ (x-w8 s 4, x-w8 s 0, x-w16 s 2, x-w32 s wd, x-flush s)                             ; DestroyWindow: the dock goes

      ; --- 6e. the screen keys, on the third screen so the leg also proves n=2: mod+r
      ;     focuses screen 2 (tag 3) and warps the pointer onto it; a crossing back
      ;     onto w6 makes the left screen current without a trade; mod+shift+r sends
      ;     w6 to screen 2's tag, where it is painted, not hidden ---
      km2 (x-keymap s (scr-mink sc) (scr-maxk sc) [114 65505])
      rk (peep km2 114 0) shk (peep km2 65505 0)                                 ; r, Shift_L
      _ (must "r-shift-keycodes" (0 < rk && 0 < shk))
      (press sh? kc) (fake 2 sk 0 0, sh? ? (fake 2 shk 0 0) 0, rest 60, fake 2 kc 0 0, rest 60,
                      fake 3 kc 0 0, rest 60, sh? ? (fake 3 shk 0 0) 0, fake 3 sk 0 0, rest 100)
      (ptrx u) (: _ (x-w8 s 38, x-w8 s 0, x-w16 s 2, x-w32 s root, x-flush s)  ; QueryPointer: root-x
                  hdr (x-reply s) (u16 hdr 16))
      (curtag u) (ask "(wscur (cap (lux-st ())))")
      _ (ask ("(sink! " + show w1 + ")"), nudge ())                               ; w1's float covers the root: sunk, the warp lands on no tag-1 window
      _ (waitp "w1-sunk" (u \ "0" = ask ("(wsfloating? (cap (lux-st ())) " + show w1 + ")")) 50)
      _ (press 0 rk)
      _ (waitp "key-screen-2" (u \ "3" = curtag ()) 50)
      _ (must "key-warped" (426 <= ptrx ()))
      g6 (rgeo w6)
      _ (fake 6 0 (g6 0 + g6 2 // 2) (g6 1 + g6 3 // 2), rest 100)              ; the pointer onto w6: its screen is current again, nothing trades
      _ (waitp "key-cross-back" (u \ "1" = curtag () && show w6 = ask "(wsfoc (cap (lux-st ())))") 50)
      _ (must "key-cross-no-trade" ("(1 2 3)" = ask "(wsvistags (cap (lux-st ())))"))
      _ (press 1 rk)
      _ (waitp "key-sent" (u \ "3" = ask ("(wstagof (cap (lux-st ())) " + show w6 + ")")) 50)
      _ (waitp "key-sent-painted" (u \ 426 <= rgeo w6 0) 50)
      _ (must "key-sent-stays" ("1" = curtag ()))
      _ (x-w8 s 4, x-w8 s 0, x-w16 s 2, x-w32 s w6, x-flush s)                 ; DestroyWindow: lux evicts it
      _ (waitp "screen-window-gone" (u \ "0" = ask ("(wsknownw? (cap (lux-st ())) " + show w6 + ")")) 50)

      ; --- 6f. a new window lands on the pointer's screen: the pointer parks on the
      ;     right screen, empty now (no window, so no crossing moves the focus), and
      ;     a fresh window is admitted to its tag and tiled there ---
      _ (fake 6 0 533 240, rest 100)
      _ (must "pointer-screen-not-current" ("1" = curtag ()))
      w7 (w1 + 10)
      _ (mkwin s w7 root)
      _ (waitp "lands-on-pointer-screen" (u \ "3" = ask ("(wstagof (cap (lux-st ())) " + show w7 + ")")) 50)
      _ (waitp "lands-painted-there" (u \ 426 <= rgeo w7 0) 50)
      _ (must "lands-current" ("3" = curtag ()))

      ; --- 6g. a float's home follows its screen: w7 floated near the right screen's
      ;     left edge, mod+left nudges it (20px a press) until its centre crosses into
      ;     the middle screen -- it becomes tag 2's, focused, and that screen current.
      ;     a tile under it on each screen (w9 right, w8 middle) and the pointer on
      ;     its body: the crossings a move paints are lux's own, so the focus holds,
      ;     and the float stays above the tiles it lands on ---
      lk (peep (x-keymap s (scr-mink sc) (scr-maxk sc) [65361]) 65361 0)          ; Left
      _ (must "left-keycode" (0 < lk))
      w8 (w1 + 11) w9 (w1 + 12)
      _ (mkwin s w9 root)                                                        ; the pointer is on the right screen: w9 tiles tag 3
      _ (waitp "w9-on-right" (u \ "3" = ask ("(wstagof (cap (lux-st ())) " + show w9 + ")")) 50)
      _ (fake 6 0 320 240, rest 100)
      _ (mkwin s w8 root)                                                        ; the middle: w8 tiles tag 2
      _ (waitp "w8-on-mid" (u \ "2" = ask ("(wstagof (cap (lux-st ())) " + show w8 + ")")) 50)
      _ (waitp "w8-painted" (u \ 213 <= rgeo w8 0) 50)
      _ (ask ("(float! " + show w7 + " '(427 10 200 150))"))                     ; centre 527: still screen 2's
      _ (nudge ())
      _ (waitp "float-on-right" (u \ "3" = ask ("(wstagof (cap (lux-st ())) " + show w7 + ")")) 50)
      _ (fake 6 0 600 100, rest 100)                                             ; the pointer onto w7's body: focused, tag 3 current
      _ (waitp "float-focused-under-pointer" (u \ show w7 = ask "(wsfoc (cap (lux-st ())))" && "3" = curtag ()) 50)
      (above? lo hi) (x-querytree s root @ [1 t] (: (go l) (? !(two? l) 0 (<l = top lo) (any (= top hi) >l) (go >l)) (go t)) 0)
      _ (must "float-above-right-tile" (above? w9 w7))
      _ (press 0 lk, press 0 lk)                                                 ; x 387: the body leaves the pointer, which lands on w9
      _ (rest 200)
      _ (must "float-keeps-focus" (show w7 = ask "(wsfoc (cap (lux-st ())))"))   ; that crossing was the move's own: not a focus
      _ (must "float-keeps-current" ("3" = curtag ()))
      _ (press 0 lk, press 0 lk, press 0 lk)                                     ; x 327, centre 427: still screen 2's
      _ (rest 200)
      _ (must "float-still-right" ("3" = ask ("(wstagof (cap (lux-st ())) " + show w7 + ")")))
      _ (press 0 lk)                                                             ; x 307, centre 407: the middle screen's
      _ (waitp "float-rehomed" (u \ "2" = ask ("(wstagof (cap (lux-st ())) " + show w7 + ")")) 50)
      _ (must "float-rehome-focus" (show w7 = ask "(wsfoc (cap (lux-st ())))"))
      _ (must "float-rehome-current" ("2" = curtag ()))
      _ (must "float-rehome-painted" (307 = rgeo w7 0))
      _ (must "float-above-mid-tile" (above? w8 w7))                             ; over w8 now, and on top of it
      _ (press 0 lk)                                                             ; one more on the new screen: still the float that moves
      _ (waitp "float-moves-on" (u \ 287 = rgeo w7 0) 50)
      _ (must "float-still-above" (above? w8 w7))
      _ (map (w \ (x-w8 s 4, x-w8 s 0, x-w16 s 2, x-w32 s w, x-flush s)) [w7 w8 w9])   ; DestroyWindow
      _ (waitp "w7-gone" (u \ "0" = ask ("(wsknownw? (cap (lux-st ())) " + show w7 + ")")) 50)
      _ (waitp "w9-gone" (u \ "0" = ask ("(wsknownw? (cap (lux-st ())) " + show w9 + ")")) 50)
      _ (fake 6 0 5 475, rest 100)                                                ; the pointer back to the left screen for the fold
      _ (delmon "left", delmon "mid", delmon "right")
      _ (refresh ())
      _ (waitp "screens-folded" (u \ "1" = nscreens ()) 50)
      _ (must "screens-cur" ("1" = ask "(wscur (cap (lux-st ())))"))

      ; --- 7. keybindings under a lock modifier: super+space (next-layout,
      ;     read back through the moor's snapshot like leg 6) must fire with
      ;     NumLock off -- and just the same with NumLock on: a lock bit rides
      ;     the KeyPress state, so the grab must cover the variant or every
      ;     chord goes dead while plain typing sails on (the 2026-07-27
      ;     symptom) ---
      kmn (x-keymap s (scr-mink sc) (scr-maxk sc) [32 65407])                     ; space, Num_Lock
      spk (peep kmn 32 0) nlk (peep kmn 65407 0)
      _ (must "space-keycode" (0 < spk), must "numlock-keycode" (0 < nlk))
      (chord u) (fake 2 sk 0 0, rest 60, fake 2 spk 0 0, rest 60,
                   fake 3 spk 0 0, rest 60, fake 3 sk 0 0, rest 100)
      (numlock u) (fake 2 nlk 0 0, rest 60, fake 3 nlk 0 0, rest 100)
      _ (chord ())
      _ (waitp "chord-flips" (u \ ! (i0 = ask chidx)) 50)                     ; the machinery works bare...
      _ (numlock ())                                                              ; ...now latch NumLock
      _ (chord ())
      _ (waitp "chord-under-numlock" (u \ = i0 (ask chidx)) 50)                 ; and the chord must still land (flip back to i0)
      _ (numlock ())                                                              ; restore

      ; --- 8. MappingNotify: poke one unused keycode's mapping (a stand-in for
      ;     setxkbmap / a keyboard replug) -- lux re-resolves and regrabs, and
      ;     the chord still lands ---
      _ (x-w8 s 100, x-w8 s 1, x-w16 s 3, x-w8 s 255, x-w8 s 1,                    ; ChangeKeyboardMapping: keycode 255 -> NoSymbol
           x-w16 s 0, x-w32 s 0, x-flush s)
      _ (rest 200)                                                               ; let the regrab land
      _ (chord ())
      _ (waitp "chord-after-remap" (u \ ! (i0 = ask chidx)) 50)
      _ (chord ())
      _ (waitp "chord-after-remap-back" (u \ = i0 (ask chidx)) 50)

      ; --- 9. float and sink are geometry, not position: a window lifted out
      ;     of the tiling and dropped back lands in the slot it left, because
      ;     it never leaves the view's zipper. read through the moor, so no X
      ;     geometry can stand in for the model ---
      wi (w1 + 7) wj (w1 + 8)
      _ (mkwin s wi root, mkwin s wj root)
      _ (rest 300)
      (rowof u) (ask "(wsrow (cap (lux-st ())))")
      r0 (rowof ())
      _ (must "row-is-three" (20 < #r0))                                  ; three ids and their parens
      _ (ask ("(float! " + (show wi + " '(10 10 120 90))")))
      _ (nudge ())
      _ (waitp "float-leaves-row" (u \ r0 != rowof ()) 50)                   ; the tiled row drops it...
      _ (ask ("(sink! " + (show wi + ")")))
      _ (nudge ())
      _ (waitp "sink-restores-row" (u \ r0 = rowof ()) 50)                      ; ...and sinking puts it back exactly

      ; --- 10. the back door: (lux-restart ()) over the moor execs in place.
      ;     the old generation is marked through its lux-cell; the reborn moor
      ;     answers with a fresh cell (the marker gone), the same pid (exec),
      ;     and the windows adopted. one connection per poll: a try that lands
      ;     on the dying generation just answers wrong and is retried ---
      (askonce q) (connect ['unix rsock] @ p
                     (!(lit? p) ? ()
                        (: _ (say p q, say p "\n", flush p)
                           r (: (go acc) (see p @ (-1 || 10) acc ch (go (acc + string ch)))
                                (go ""))
                           (close p, r))))
      _ (ask "(pin lux-cell 'gen 'old)")
      pid0 (ask "(getpid 0)")
      (say rc "(lux-restart ())\n", flush rc,
       waitp "restart-reborn" (u \ = "()" (askonce "(peep lux-cell 'gen ())")) 100,
       waitp "restart-same-pid" (u \ = pid0 (askonce "(getpid 0)")) 50,
       waitp "restart-adopts" (u \ any (k \ = k wr) (x-getprop-atoms s root a-li)) 100,
       close rc,

       close s3, close s,
       line "probe: manage + maximize + move + resize + focus + activate + moor + close, all exact",
       quit 0)))
