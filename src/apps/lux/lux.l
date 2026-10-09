; src/apps/lux/lux.l -- the driver: wire the pure core (src/apps/lux/core.l), the layout engine
; (src/apps/lux/layout.l), the manageHook (src/apps/lux/manage.l), the keymap (src/apps/lux/keys.l), and EWMH
; (src/apps/lux/ewmh.l) over the X protocol (src/apps/lux/wire.l), configured by src/apps/lux/config.l.
; Concatenate them:
;   cat src/apps/lux/{core,layout,wire,ewmh,manage,keys,config,lux}.l | love
; (against `Xephyr :7 -ac`, or a real server with lux-auth set). Rung 8: the
; driver reads the config -- border width and colors (focused/normal pixels),
; workspaces, the layout stack, hooks, keymap, startup spawns -- and runs until
; the display dies or (quit). The f_t hinge: a float-focused chord moves/
; resizes the float, a tile-focused one messages the layout / navigates. the
; sheaf's zipper holds every window on a view, so wsfoc names the focus whatever
; its kind and no float focus rides beside it; hist is nextMatch's mru focus ring;
; lays is the layout book, one layout per tag (xmonad's per-workspace layout).

; --- the lux repl: a unix-socket moor into the running wm (the dock's shape,
; crew-side; `nc <sock>` is the client). Forms eval in the book, so every
; global is a verb; the live (sh lays hist) state rides lux-cell -- reads
; take the snapshot ((lux-st ())), changes queue a state function through
; (lux! f), and the driver's loop drains the queue at its next X event,
; guarded: a change must answer a 3-list whose sheaf is wssane? -- the proved
; invariant, standing as a live seatbelt -- or it is refused and the old
; state kept. one hand on the wire: the repl never touches any X socket (the
; the painter's law, absolute); with layout.l's open dispatch lane,
; (lay! [my-closure state..]) swaps in a layout written at the prompt.
; The socket is an eval server -- $xdg_runtime_dir (0700) when set, /tmp
; otherwise (a socket refuses connect without write permission). The socket
; is also the back door when the chords are dead or an install went in:
;   echo '(lux-restart ())' | nc -U $xdg_runtime_dir/lux-<n>.sock
; execs the script in place (same pid; the adoption sweep keeps every
; window). The live socket is the one that accepts; dead generations'
; leftovers are swept at moor start (lux-sweep).
(borrow 'xwire)   ; the X wire, src/apps/lux/wire.l
(borrow 'posix)
(: lux-cell {}
   (lux-st u) (lux-cell 'st)
   ; a change queues; the driver's loop drains at its next X event. On a live
   ; desktop that is imminent (any motion, focus or property tick); a headless
   ; harness nudges with any event of its own (boot/luxui-probe.l sends a
   ; no-op ClientMessage). Deliberately no wake wire from lux's side: a poke
   ; connection made Xvfb close-down an innocent client whose id range rode a
   ; recycled slot (gdb: ospoll_wait -> CloseDownClient -> FreeClientResources
   ; with the victim's socket provably open) -- one hand on the wire, and the
   ; wire is the driver's alone.
   (lux! f) (pin lux-cell 'q (f . lux-cell 'q), 'queued)                 ; (a peep+pin pair -- a concurrent drain in the gap can lose
                                                                         ;  a change; prompt-scale odds, and wssane? guards either way)
   ; the book: lays is ((tag lay)..), a tag without an entry on the configured stack
   (lay-at lays t) (lays-of lays t lux-layout)
   (cur-lay sh lays) (lay-at lays (wscur sh))
   (lays-send lays t msg z)                                                      ; sendMessage to one tag's layout; unhandled (()) keeps the book
    (lay-msg (lay-at lays t) msg z @ l2 (l2 ? (lays-put lays t l2) lays))
   ; the command sugar -- each a (lux! ..) over the snapshot shape (sh lays hist),
   ; addressing the current tag's layout
   (lay u)   (lux-st () @ st (cur-lay <st <>st))
   (lay! l)  (lux! (st \ [<st (lays-put <>st (wscur <st) l) (st 2)]))
   (msg! m)  (lux! (st \ [<st (lays-send <>st (wscur <st) m (wstilez <st)) (st 2)]))
   (sink! w) (lux! (st \ [(wssink <st w) <>st (st 2)]))
   (float! w r) (lux! (st \ [(wsdofloat <st w r) <>st (st 2)]))
   (row u) (wsrow <(lux-st ()))

   ; the moor: shore the socket, twirl a session per client -- read every form
   ; a line completes, eval through the self-hosted ev, show the value back.
   ; deliberate orphans, like the dock's: lux runs forever.
   (lux-rundir u) (getenv "XDG_RUNTIME_DIR" @ rd (1 < #rd ? rd "/tmp"))
   (lux-sock u) (lux-rundir () + "/lux-" + lux-dispnum () + ".sock")
   ; the sweep: an exec'd restart and a dead Xephyr session both drop their
   ; moor fd without unlinking, so lux-*.sock files pile up in the rundir.
   ; probe every sibling: a refused connect is a dead one, unlink it; a live
   ; other-display lux answers and keeps its socket.
   (lux-sweep own)
    (: dir (lux-rundir ())
       (sockish? n) (n @ ("lux-" + _ + ".sock") 1 0)
       (dead? p) (connect ['unix p] @ c (hot? c ? (close c, 0) 1))
       (go ns acc) (? !(two? ns) acc
                    (dir + ("/" + <ns) @ p
                     (p != own && dead? p ? (unlink p, go >ns (p . acc))
                      (go >ns acc))))
       (go (filter sockish? (readdir dir)) ()))
   ; our script path, either argv shape: plain `love lux` gives (script ..);
   ; the -l shebang gives the raw OS argv (love -l script ..) -- the -l operand
   (lux-self u) (:- (go argv) (go m)
    (? !(two? m) <argv
       (<m = "-l") (two? >m ? <>m <argv)
       (go >m)))
   ; restart-in-place from the moor -- the door when the chords are dead (a
   ; wedged driver, an upgraded install): exec drops the cloexec'd sockets,
   ; the redirect releases, the new generation adopts every window. same pid.
   ; the exact original argv first (exec is execvp, so `love` re-resolves off
   ; PATH -- an upgraded binary lands on the first restart, and a dev pile of
   ; -l modules re-runs whole); the script and the seat itself as fallbacks.
   ; the argv a restart execs: run as the verb (`love lux`), this very binary as that verb
   ; again -- PATH may hold another lux, or none -- else the original argv
   (lux-argv u) (<argv = "lux" ? ((selfpath 0) . argv) argv)
   (lux-restart u) (say out "lux: restart over the moor -- exec\n", flush out,
                    exec (lux-argv ()),
                    exec [(lux-self ())],
                    exec [(selfpath 0) (lux-self ())],
                    'restart-failed)
   ; the session reads lines (see parks the TASK -- the reader's park law) and
   ; sounds the TEXT: `sound` walks a charlist, so a socket running dry mid-skip
   ; cannot strand the whole vm in a C parse the way sounding the fd once did (an
   ; idle attached client froze the wm between asks; a painter starved on
   ; exactly this). a torn shape carries to the next line as the residue the
   ; reader hands back -- not the accumulation re-read from byte zero -- and
   ; every form on a line runs, where only the first used to.
   (lux-session c)
    (: (rdline acc) (see c @ -1 () 10 (rev (10 . acc)) ch (rdline (ch . acc)))
       (go pend) (rdline () @ cl
                    (? !(two? cl) 0
                       ((: (h cl) (sound cl @ r
                                     (? (two? r) (ev <r @ v
                                                    (say c (show v + "\n"),
                                                     flush c,
                                                     h >r))
                                        (r = 'torn) (go cl)
                                        (go ()))))
                        (pend + cl))))
       (go ()))
   (lux-moor path)
    (: gone (lux-sweep path)
       _ (two? gone ? (say out ("lux: swept " + (show #gone + " stale socket(s)\n")),
                       flush out))
       lp (listen ['unix path])
       (? !(lit? lp) (say out ("lux: no moor at " + (path + "\n")), flush out)
          (: _ (say out ("lux: moored at " + (path + "\n")))
             _ (flush out)
             (knock _) (: _ (await lp)
                          c (accept lp)
                          (lit? c ? (twirl (_ \ (lux-session c, close c)) 0) 0,
                           knock ()))
             (knock ())))))

; a welp-face help so a scare returns a visible value (to the repl client, or
; at a driver raise site) instead of dropping the wm -- the dock's shape:
; answer ('scare a b), the only bit a help sees.
(hear (a \ b \ ['scare a b]))

(: s (x-connect lux-display)
   _ (hot? s ? 0 (say err "lux: no display -- Xephyr up?\n", quit 1))
   (line m) (say out m, say out "\n", flush out)
   sc (x-setup s lux-auth)
   _ (sc ? 0 (say err "lux: setup refused (auth?)\n", quit 1))
   root (scr-root sc) wpx (scr-w sc) hpx (scr-h sc)
   _ (x-redirect s root ? 0 (say err "lux: another WM owns this display\n", quit 1))
   _ (line ("lux: managing " + show root + " " + show wpx + "x" + show hpx))
   _ (ewmh-init s root (scr-idbase sc) lux-tags)                          ; the support window + _net_* root properties
   rr (x-randr-init s root)                                                      ; randr 1.5: the monitors are the screens, their changes events
   _ (line (rr ? ("lux: randr events from " + show <>rr) "lux: no randr 1.5 -- the root is the one screen"))

   ; --- the config's face: border pixels, the root cursor, the startup spawns ---
   npix (x-color s (scr-cmap sc) lux-normal-color)
   fpix (x-color s (scr-cmap sc) lux-focused-color)
   _ (line ("lux: colors " + show npix + " " + show fpix))
   _ (x-cursor s root (scr-idbase sc + 1) (scr-idbase sc + 2))                   ; setDefaultCursor xC_left_ptr
   _ (map spawn lux-startup)

   ; --- keyboard: resolve the keymap's keysyms to keycodes, grab every chord.
   ;     each chord is grabbed once per lock variant (bare, CapsLock=2, Mod2=16,
   ;     both): a latched lock rides the KeyPress state and an exact-modifier
   ;     grab misses it -- every binding dead while plain typing sails on
   ;     (kmodmask already masks the lock bits back out at match time). the
   ;     table lives in a cell so MappingNotify can re-resolve and regrab. ---
   (keys-resolve u) (x-keymap s (scr-mink sc) (scr-maxk sc) (keys-syms lux-keymap) @ km
                       (filter (r \ <>r > 0)                                   ; rows (lib keycode action); keysym absent -> dropped
                               (map (r \ [(kb-mods r) (peep km (kb-sym r) 0) (kb-act r)]) lux-keymap)))
   (keys-grab tab) (map (r \ map (lm \ x-grab s root (lm | <r) <>r) '(0 2 16 18)) tab,
                      x-flush s)
   ktabc {}
   (ktab u) (ktabc 0)
   _ (pin ktabc 0 (keys-resolve ()))
   _ (keys-grab (ktab ()))
   _ (line ("lux: grabbed " + show #(ktab ()) + " chords"))

   ; --- rendering (the layout engine answers, X obeys) ---
   scrc {} _ (pin scrc 0 [0 0 wpx hpx])                                         ; the screen rect lives in a cell: randr reshapes it
   (scrn u) (scrc 0)
   (trect-of r) (scrn () @ sr (ewmh-rect r (sr 2) (sr 3)))                       ; a screen's tiling rect: minus dock struts (sup+b flips)
   (cur-rect sh) (wsrectof sh (wscur sh) @ r (r ? r (scrn ())))                   ; the current screen's rect
   (screens u) ((rr ? (x-monitors s rr root) ()) @ ms (two? ms ? ms [(scrn ())]))   ; the monitors, else the whole root
   (under-pointer sh) (: p (x-queryptr s root) t (wsscreenat sh <p <>p)          ; the pointer's screen becomes current (a crossing
                         (t ? (wsview sh t) sh))                                  ; only fires over a window; an empty screen has none)
   (rescreen sh) (under-pointer (wsrescreen sh (screens ())) @ sh2               ; re-read the screens into the sheaf, saying so when they moved
                    (sh2 = sh ? 0 (line ("lux: screens " + show (wsvis sh2))), sh2))

   ; --- the unmap ledger (xmonad's mapped + waitingUnmap): map!/hide! track our
   ;     own intent at send time -- mapd holds the windows we have mapped, owed
   ;     counts the unmap echoes we're owed back. a real UnmapNotify with no
   ;     echo owed is the client's own unmap: a withdraw, whether or not the
   ;     ICCCM courtesy synthetic ever comes (a toolkit that skips it still
   ;     gets evicted instead of a window that can never disappear). ---
   mapd (tablet 8) owed (tablet 8)
   (map! w) (pin mapd w 1, x-map s w, fwin w @ f (f = w ? 0 (x-map s f)))
   (hide! w) (fwin w @ f (f = w ? 0 (x-unmap s f)),
              peep mapd w 0 ? (pin owed w (1 + peep owed w 0)) 0,              ; only a mapped window echoes -- an unmap of the
              pull mapd w 0, x-unmap s w)                                        ; already-hidden fires no event, so no count

   ; --- frames: a managed window rides in a frame of its own size plus the border,
   ;     the client inside -- a reparenting wm, so a toolkit that assumes one (java's awt)
   ;     places itself right. the frame takes the client's depth and visual (a
   ;     compositor reads alpha off the top-level), moves and stacks; override-redirect,
   ;     so a restart's sweep never adopts a stale one. the border is the frame's own
   ;     background around the client at (bw bw), never an X border: a border change is
   ;     a size change, which a compositor that renames its pixmap only on a resize sees.
   ;     the client is resized only when its size changes and told its root
   ;     geometry (ICCCM 4.2.3) when the frame moves; an unchanged place sends nothing.
   ;     a frame record: 'f the frame, 'own its own visual, 'g (x y w h bw) as placed,
   ;     'bw the border the next move! lays, 'px. a client's parent is its frame ---
   frm (tablet 8) fidc {'n 16 'free ()} cmaps (tablet 4)
   (fid u) (fidc 'free @ fr (two? fr ? (pin fidc 'free >fr, <fr)
                               (fidc 'n @ n (pin fidc 'n (n + 1), scr-idbase sc + n))))
   (fwin w) (peep frm w () @ r (r ? (r 'f) w))                                    ; what moves and stacks: the frame, else the window
   (visdepth w)                                                                  ; -> (visual depth) | ()
    (: _ (x-w8 s 3, x-w8 s 0, x-w16 s 2, x-w32 s w, x-flush s)                   ; GetWindowAttributes: the visual at byte 8
       a (x-reply s) _ (<a = 1 ? (x-rbytes s (u32 a 4 * 4)) 0)
       _ (x-w8 s 14, x-w8 s 0, x-w16 s 2, x-w32 s w, x-flush s)                  ; GetGeometry: the depth at byte 1
       g (x-reply s)
       (<a = 1 && <g = 1 ? [(u32 a 8) (g 1)] ()))
   (frame! w g)                                                                  ; g: the client's root rect
    (visdepth w @ vd
       (? !vd 0
          (: f (fid ()) own (vd 1 != scr-depth sc || <vd != scr-visual sc)
             cm (? !own 0 (peep cmaps <vd 0) (peep cmaps <vd 0)
                   (fid () @ m (x-w8 s 78, x-w8 s 0, x-w16 s 4, x-w32 s m, x-w32 s root, x-w32 s <vd,   ; CreateColormap, alloc None
                                pin cmaps <vd m, m)))
             (x-w8 s 1, x-w8 s (own ? (vd 1) 0), x-w16 s (own ? 12 10), x-w32 s f, x-w32 s root,      ; CreateWindow, no background
              x-w16 s (g 0), x-w16 s (g 1), x-w16 s (mx2 1 (g 2)), x-w16 s (mx2 1 (g 3)), x-w16 s 0, x-w16 s 1,
              x-w32 s (own ? <vd 0),
              (own ? (x-w32 s 10760, x-w32 s 0, x-w32 s 1, x-w32 s 1572864, x-w32 s cm)   ; border-pixel, override-redirect,
                     (x-w32 s 2560, x-w32 s 1, x-w32 s 1572864)),                          ; event-mask (substructure redirect+notify), colormap
              peep mapd w 0 ? (pin owed w (1 + peep owed w 0)) 0,               ; reparenting a mapped window unmaps it: an echo owed
              x-w8 s 6, x-w8 s 0, x-w16 s 2, x-w32 s w,                          ; ChangeSaveSet Insert: our exit hands it back to the root
              x-border s w 0,
              x-w8 s 7, x-w8 s 0, x-w16 s 4, x-w32 s w, x-w32 s f, x-w16 s 0, x-w16 s 0,   ; ReparentWindow into the frame at (0 0)
              x-chprop32 s w (ewmh-atom "_NET_FRAME_EXTENTS") 6 '(0 0 0 0),
              pin frm w {'f f 'own own 'g [(g 0) (g 1) (g 2) (g 3) 0] 'bw 0 'px -1},
              f))))
   (unframe! w back)                                                             ; the frame goes; back: the client returns to the root first
    (peep frm w () @ r
       (r ? (: f (r 'f) g (r 'g)
               (back ? (x-w8 s 7, x-w8 s 0, x-w16 s 4, x-w32 s w, x-w32 s root, x-w16 s (g 0 + g 4), x-w16 s (g 1 + g 4),
                        x-w8 s 6, x-w8 s 1, x-w16 s 2, x-w32 s w) 0,               ; ChangeSaveSet Delete
                x-w8 s 4, x-w8 s 0, x-w16 s 2, x-w32 s f,                         ; DestroyWindow
                pin fidc 'free (f . fidc 'free), pull frm w 0)) 0))
   (synconf w x y cw ch)                                                         ; a synthetic ConfigureNotify: the client's root geometry
    (x-w8 s 25, x-w8 s 0, x-w16 s 11, x-w32 s w, x-w32 s 131072,                 ; SendEvent, mask StructureNotify
     x-w8 s 22, x-w8 s 0, x-w16 s 0, x-w32 s w, x-w32 s w,
     x-w32 s 0, x-w16 s x, x-w16 s y, x-w16 s cw, x-w16 s ch,
     x-w16 s 0, x-w16 s 0, x-w32 s 0)
   (tell! w) (peep frm w () @ r                                                  ; a ConfigureRequest overruled: its answer
               (r ? (r 'g @ g (synconf w (g 0 + g 4) (g 1 + g 4) (g 2) (g 3))) (x-confnotify s w)))
   (geom w) (peep frm w () @ r (r ? (take 4 (r 'g)) (x-getgeom s w)))           ; (x y w h) as the screen sees it
   (bord! w bw px)                                                               ; a frame's width waits for the move! that follows
    (peep frm w () @ r
       (? !r (x-border s w bw, x-borderpix s w px)
          (: f (r 'f) p (r 'own ? (px | 4278190080) px)                          ; a 32-bit frame's pixel carries opaque alpha
             (pin r 'bw bw,
              r 'px = p ? 0 (x-bgpix s f p, x-clear s f, pin r 'px p)))))
   (move! w x y cw ch)                                                           ; (x y) the outer corner, (cw ch) the client
    (peep frm w () @ r
       (? !r (x-configure s w x y cw ch)
          (: g (r 'g) bw (r 'bw)
             ([x y cw ch bw] = g ? 0
                (x-configure s (r 'f) x y (cw + 2 * bw) (ch + 2 * bw),
                 g 2 = cw && g 3 = ch && g 4 = bw ? 0 (x-configure s w bw bw cw ch),
                 pin r 'g [x y cw ch bw],
                 synconf w (x + bw) (y + bw) cw ch)))))
   (unled! w) (pull mapd w 0, pull owed w 0)                              ; the window left management: clear its ledger
   (render sh lays)                                                               ; every screen: its tag's placements configured, the dropped unmapped, floats on top
    (: f (wsfoc sh)                                                              ; the focus is the sheaf's, float or tile alike
       (tiles p)                                                                 ; one screen (tag rect): tile the tag into its rect, answer the placed
        (: t <p pls <(lay-tile (lay-at lays t) (trect-of <>p) (wstilezof sh t))
           _ (map (q \ (: w (q 0) bw (#q < 6 ? lux-border (q 5))                ; smartBorders sets 0 on a singleton/fullscreen
                         (bord! w bw (w = f ? fpix npix),                        ; focusedBorderColor / normalBorderColor
                          move! w (q 1) (q 2)                                    ; the client is the tile less its border
                                (mx2 1 (q 3 - 2 * bw)) (mx2 1 (q 4 - 2 * bw))))) pls)
           (map cap pls))
       placed (foldl (a \ p \ a + tiles p) () (wsvis sh))
       (map (w \ any (= w) placed || wsfloating? sh w ? 0 (hide! w)) (wsonscreen sh),     ; tiles the layouts dropped (Full/minimize): hide them
        map map! placed,                                                         ; (re)map placed -- a no-op on the already-mapped
        map (p \ (<>p @ r                                                        ; floating windows at home on a screen: place, map, raise above the tiles
                   (map (fp \ (: w <fp fr <>fp
                                 bw (fr = r ? 0 lux-border)                      ; a fullscreen float (its screen is its rect) wears no border
                                 (bord! w bw (w = f ? fpix npix),
                                  move! w (fr 0) (fr 1) (fr 2) (fr 3),
                                  map! w, x-raise s (fwin w)))) (wsvisflof sh <p)))) (wsvis sh),
        x-clear-enters s))                                                       ; the crossings this paint caused are not the user's
   (refocus sh) (wsfoc sh @ f                                                   ; an empty view takes the root: PointerRoot would
                   (x-focus s (f ? f root), x-flush s))                         ; hand the keys to whatever the pointer sits over
   (watch w) (x-cwa-events s w 16, x-grabbtn s w)                         ; the mouse wires: EnterWindow selected (focus follows the
                                                                                 ; pointer in) + buttons 1-3 sync-grabbed (click-to-focus)
   (switch sh lays t)                                                             ; view (greedy: the tag comes to this screen): paint, then hide what left every screen
    (? (t = wscur sh || !(wsknown? sh t)) sh
       (: was (wsonscreen sh) sh2 (wsgreedy sh t) now (wsonscreen sh2)
          (map map! (filter (w \ !(any (= w) was)) now),                         ; the arriving ring, tiles and floats alike
           render sh2 lays,
           map hide! (filter (w \ !(any (= w) now)) was), x-clear-enters s,
           line ("lux: view " + show t + " " + show (wsrow sh2)),
           sh2)))

   ; --- do-act: interpret one keys.l action. Returns by looping. ---
   (do-act a sh lays hist)
    (: k <a z (wstilez sh) fw (wsfoc sh)                                         ; the layout reads the tiled zipper; fw is simply the focus
       (screen-tag n) (wsvistags sh @ ts (n < #ts ? (ts n)))                    ; the tag on screen n, () past the last screen
       (relay sh2 lays2) (render sh2 lays2,                                        ; render, focus whatever the sheaf focuses, loop
                          refocus sh2,
                          loop sh2 lays2 hist)
       (? (k = 'msg) (relay sh (lays-send lays (wscur sh) <>a z))
          (k = 'focus-dn) (relay (wsmap sh zfocdn) lays)                          ; the ring IS the zipper: one op, no branch on kind
          (k = 'focus-up) (relay (wsmap sh zfocup) lays)
          (k = 'focus-master) (relay (wsmap sh (zfocto <(wsrow sh))) lays)        ; the first TILE: a float is never master
          (k = 'swap-dn) (relay (wsswapdn sh) lays)                               ; the order ops permute tiled slots, floats keep theirs
          (k = 'swap-up) (relay (wsswapup sh) lays)
          (k = 'swap-master) (relay (wsmaster sh) lays)
          (k = 'view) (relay (switch sh lays <>a) lays)                            ; switch renders but does not focus: relay is what makes
                                                                                 ; the keyboard agree with the arriving view
          (k = 'shift) (: t <>a sh2 (shiftwin sh fw t)                           ; the focus emigrates, float or tile, rect and all
                          (render sh2 lays,
                           sh2 = sh || wsvisible? sh2 t ? 0 (hide! fw, x-clear-enters s),     ; it left every screen: hide the emigrant
                           line ("lux: sent " + show fw + " -> " + show t),
                           loop sh2 lays hist))
          (k = 'screen)                                                          ; focus screen n: its tag becomes current, the pointer follows
          (screen-tag <>a @ t
             (!t || t = wscur sh ? (loop sh lays hist)
                (wsrectof sh t @ r
                   (x-warp s root (r 0 + r 2 // 2) (r 1 + r 3 // 2),
                    relay (wsview sh t) lays))))
          (k = 'to-screen)                                                       ; send the focus to screen n's tag
          (screen-tag <>a @ t (t && fw ? (do-act ['shift t] sh lays hist) (loop sh lays hist)))
          (k = 'spawn) (spawn <>a @ p (line ("lux: spawn " + (<<>a + " " + show p)),
                                       loop sh lays hist))
          (k = 'exec) (line "lux: exec -- abdicating", exec <>a,          ; returns only on failure
                       loop sh lays hist)
          (k = 'kill) (fw ? (x-has-atom s fw "WM_PROTOCOLS" "WM_DELETE_WINDOW" ?           ; ask first (killWindow): KillClient
                               (x-wmdel s fw) (x-kill s fw),                     ; takes the whole client, every window it owns
                              x-flush s) 0,                                      ; DestroyNotify does the eviction
                       line ("lux: kill " + show fw), loop sh lays hist)
          (k = 'quit) (line "lux: quit")                                          ; fall out of the loop
          (k = 'restart)                                                         ; restart-in-place: exec the original argv (execvp, so love
          (line ("lux: restart -- exec, pid " + show (getpid 0)),            ; re-resolves off PATH -- an upgraded binary lands first try,
           exec (lux-argv ()),                                               ; and a dev pile of -l modules re-runs whole; exec'ing
           exec [(lux-self ())],                                            ; the seat path would pin a deleted build forever). the
           exec [(selfpath 0) (lux-self ())],                               ; cloexec'd socket drops, the redirect releases, the new
           line "lux: restart failed",
           loop sh lays hist)                                                ; generation adopts the survivors
          (k = 'refresh) (relay (rescreen sh) lays)                             ; and re-read the screens: a client monitor change sends no event
          (k = 'reset-layout) (relay sh (lays-put lays (wscur sh) lux-layout))
          (k = 'toggle-struts) (ewmh-toggle (), line "lux: toggle struts", relay sh lays)
          (k = 'sink) (wsfloating? sh fw ? (relay (wssink sh fw) lays) (loop sh lays hist))
          (k = 'float-toggle)
          (? !fw (loop sh lays hist)
             (wsfloating? sh fw) (relay (wssink sh fw) lays)
             (line ("lux: float " + show fw), relay (wsdofloat sh fw (geom fw)) lays))
          (k = 'next-match)
          (nm-pick (wsring sh) fw hist <>a @ t                                   ; the whole ring -- floats too, anchored at the focus
             (t ? (relay (wsmap sh (zfocto t)) lays) (loop sh lays hist)))
          ; --- the directional trio: the f_t hinge ---
          (wsfloating? sh fw)                                                    ; float focused: move (go) or resize (swapd/resize)
          (: r (wsrect sh fw) d (a 2) dx <d dy <>d
             r2 (k @ 'go [(r 0 + dx) (r 1 + dy) (r 2) (r 3)]
                 [(r 0) (r 1) (mx2 20 (r 2 + dx)) (mx2 20 (r 3 + dy))])
             (relay (wsdofloat sh fw r2) lays))
          (: dir <>a pls <(lay-tile (cur-lay sh lays) (trect-of (cur-rect sh)) z) tgt (nav-target pls fw dir)
             (k @ 'go (tgt ? (relay (wsmap sh (zfocto tgt)) lays) (loop sh lays hist))
               'swapd (tgt ? (relay (wsmap sh (zswapw fw tgt)) lays) (loop sh lays hist))
                      (relay sh (lays-send lays (wscur sh) (dir @ ('left || 'down) 'shrink 'expand) z))))))

   ; --- pointer drag (xmonad's mouseBindings): the window follows the pointer
   ;     ('move) or its far corner does ('resize). g0 is the start rect, (rx0 ry0)
   ;     the start pointer; a release/motion carries the live pointer at bytes
   ;     20/22. The final rect is recomputed from the release position, so no
   ;     rect need thread through the loop. Other events are dropped for the
   ;     drag's duration -- the pointer is grabbed, the user is not spawning. ---
   (drag-rect mode g0 rx0 ry0 rx ry)
    (: dx (rx - rx0) dy (ry - ry0)
       (mode @ 'move [(g0 0 + dx) (g0 1 + dy) (g0 2) (g0 3)]
        [(g0 0) (g0 1) (mx2 40 (g0 2 + dx)) (mx2 40 (g0 3 + dy))]))
   (drag mode w g0 rx0 ry0)
    (x-next s @ e
       (? !e g0                                                                 ; display gone: keep the start rect
          (ev-code e = 6) (: pkt (ev-raw e)                                     ; MotionNotify: reconfigure live
                                g1 (drag-rect mode g0 rx0 ry0 (u16 pkt 20) (u16 pkt 22))
                                (move! w (g1 0) (g1 1) (g1 2) (g1 3), x-flush s,
                                 drag mode w g0 rx0 ry0))
          (ev-code e = 5) (ev-raw e @ pkt (drag-rect mode g0 rx0 ry0 (u16 pkt 20) (u16 pkt 22)))       ; ButtonRelease: settle
          (drag mode w g0 rx0 ry0)))                                            ; anything else mid-drag: ignore

   ; --- the repl gate: every pass through the loop publishes the snapshot and
   ;     drains (lux!) changes, each guarded -- a change must answer a 3-list
   ;     whose sheaf is wssane? (the proved invariant, live) or it is refused
   ;     and the old state kept. a scare inside a change answers ('scare a b)
   ;     through the help above -- not a 3-list, so it refuses the same way. ---
   (loop sh lays hist)
    (: q (pull lux-cell 'q ())
       (? !(two? q) (pin lux-cell 'st [sh lays hist],
                          loop2 sh lays hist)
          (: st (foldl (acc \ f \ (f acc @ r
                                     (two? r && 3 = #r && wssane? <r ? r
                                        (line "lux: change refused", acc))))
                       [sh lays hist] (rev q))
             _ (pin lux-cell 'st st)                                            ; the snapshot rides post-drain, so a moor read sees the change
             sh2 <st lays2 <>st
             (render sh2 lays2,
              refocus sh2,
              line ("lux: changed x" + show #q),
              loop2 sh2 lays2 (st 2)))))

   ; --- the event loop: (sheaf, layout, focus-history).
   ;     the mru param is hist0, the fresh ring hist: a `:` binding shadows a
   ;     same-named parameter over the whole form (one scope, no escape), so
   ;     `hist (?  .. hist ..)` read the zero point every pass -- the ring
   ;     never accumulated. name the parameter apart and the ring lives. ---
   (loop2 sh lays hist0)
    (: f (wsfoc sh)                                                              ; the mru rides the focus: floats enter too
       hist (f && f != (two? hist0 ? <hist0 ()) ? (f . znub f hist0) hist0)
       (relay sh2 lays2) (render sh2 lays2,                                        ; render, focus, loop (do-act has its own)
                          refocus sh2,
                          loop sh2 lays2 hist)
       _ (glean 0)                                                                ; glean one spawned zombie home, if any
       _ (ewmh-sync s sh (scrn ()))                                              ; publish the sheaf to pagers (change-guarded)
       e (x-next s)
       (? !e (line "lux: display gone")
          (ev-code e = 0)                                                        ; an X error. the code alone names neither the request
          (ev-raw e @ pkt                                                        ; nor the resource, so a window that died between its
             (line ("lux: X error " + show (ev-detail e) +                    ; unmap and our delprop reads exactly like a real bug
                      " req " + show (pkt 10) + "." + show (u16 pkt 8) +
                         " id " + show (u32 pkt 4)),
              loop sh lays hist))
          (: code (ev-code e) win (ev-window e)
             (? (code = 20 && wsknownw? sh win)                                ; MapRequest from a window we already manage: ignore it
                (line ("lux: remap " + show win), loop sh lays hist)          ; (mapping it here would paint it OVER a workspace it
                (code = 20)                                                      ; isn't on -- the "one window on two workspaces" bug)
                                                                                 ; MapRequest: admit tiled, run the manageHook, then place
                (: st (ewmh-track s win) _ (st ? (line ("lux: strut " + show win)) 0)   ; a dock's strut shrinks the tiling rect
                   sh1 (admit (under-pointer sh) win)                          ; a new window lands where the pointer is
                   c (mg-ctx s win (cur-rect sh) (x-getgeom s win))
                   sh2 (manage-window lux-manage c sh1)
                   (wsknownw? sh2 win ?                                          ; managed (tiled or floated) -> place it
                      (x-chprop32 s win (x-intern s "WM_STATE") (x-intern s "WM_STATE") '(1 0),    ; the ICCCM stamp: a restart finds us even hidden
                       watch win,
                       frame! win (x-getgeom s win),
                       render sh2 lays,
                       map! win,
                       refocus sh2,                                        ; admit focused it: a fresh window takes the keyboard

                       line ("lux: + " + show win + " " + show (wsrow sh2)),
                       loop sh2 lays hist)
                      (x-cwa-events s win 4194304,                         ; PropertyChange: a dock may move its strut later
                       x-map s win,                                         ; ignored: map raw -- a desktop under everything, a dock/notification on top
                       st ? (render sh2 lays) 0,                              ; a strut reshapes the tiles now, not at the next event
                       x-has-atom s win "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DESKTOP" ?
                         (x-lower s win) (x-raise s win),
                       x-flush s,
                       line ("lux: ignore " + show win),
                       loop sh2 lays hist)))
                (code = 19) (win = wsfoc sh ? (x-focus s win, x-flush s), loop sh lays hist)          ; MapNotify: focus if it's the top
                (code = 17)                                                      ; DestroyNotify: unmanage + tile
                (ewmh-untrack win, unled! win, unframe! win 0,
                 (? !(wsknownw? sh win) (loop sh lays hist)
                  (evict sh win @ sh2
                     (line ("lux: - " + show win + " " + show (wsrow sh2)),
                      relay sh2 lays))))                                       ; zdel already moved the focus on; relay follows it
                (code = 18)                                                     ; UnmapNotify: xmonad's waitingUnmap rule. Our own hides echo
                (? !(wsknownw? sh win) (loop sh lays hist)                        ; back counted (the owed ledger); a synthetic (send-event bit
                   (: syn (127 < <(ev-raw e)) p (peep owed win 0)                ; on the raw byte) is a withdraw (ICCCM 4.1.4) -- and so is a
                      (!syn && 0 < p ?                                           ; real one we're owed no echo for: the client unmapped it,
                         (pin owed win (p - 1), loop sh lays hist)         ; courtesy synthetic or not
                         (: _ (ewmh-untrack win)
                            _ (x-delprop s win (x-intern s "WM_STATE"))          ; unstamp: a restart must not re-adopt the withdrawn
                            sh2 (evict sh win)                                   ; (the tray ghost); a re-map arrives as a fresh MapRequest
                            (x-unmap s win,                                      ; a crossing's render in the event gap may have re-mapped
                             unframe! win 1,                                      ; back to the root, as it came
                             unled! win,                                         ; it (telegram's media viewer): withdrawn means unmapped
                             line ("lux: withdraw " + show win),
                             relay sh2 lays)))))
                (code = 7)                                                      ; EnterNotify: focus follows the pointer (normal crossings
                (: pkt (ev-raw e) w (u32 pkt 12)                                 ; only -- the window is the event field, byte 12)
                   (? (pkt 30 != 0 || ev-detail e = 2)                  ; mode Grab/Ungrab or detail Inferior: not a real entry
                      (loop sh lays hist)
                      (!(wsknownw? sh w) || w = wsfoc sh) (loop sh lays hist)   ; unmanaged, or already focused: still
                      (relay (wsfocw sh w) lays)))                               ; on another screen: that screen becomes current
                (code = 4)                                                      ; ButtonPress via the sync grab: super+drag moves/resizes a
                (: pkt (ev-raw e) w (u32 pkt 12) btn (ev-detail e) st (ev-state e)   ; float (xmonad mouseBindings); a plain click focuses
                   (? (st & lux-mod && wsknownw? sh w && (btn = 1 || btn = 3))    ; mod+btn1 move, mod+btn3 resize -- float first, then drag
                      (: sh2 (wsfloating? sh w ? sh (wsdofloat sh w (geom w)))
                         g0 (geom w) rx0 (u16 pkt 20) ry0 (u16 pkt 22)
                         _ (x-focus s w) _ (x-raise s (fwin w))
                         _ (x-grabptr s w) _ (x-allow-async s) _ (x-flush s)     ; capture motion, thaw the sync freeze without replaying
                         gf (drag (btn @ 1 'move 'resize) w g0 rx0 ry0)
                         (x-ungrabptr s, x-flush s,
                          line ((btn @ 1 "lux: moved " "lux: resized ") + show w),
                          relay (wsdofloat (wsfocw sh2 w) w gf) lays))
                      (st & lux-mod && wsknownw? sh w && btn = 2)                ; mod+btn2: promote the clicked window to master (shiftMaster)
                      (x-allow-async s, x-flush s,
                         relay (wsmaster (wsfocw sh w)) lays)
                      (x-replay s, x-flush s,                                   ; a plain click: hand it to the app, then click-to-focus
                       (? (!(wsknownw? sh w) || w = wsfoc sh) (loop sh lays hist)
                          (relay (wsfocw sh w) lays)))))
                (code = 2)                                                       ; KeyPress: the table answers
                (: kc (ev-detail e) stm (ev-state e & kmodmask)
                   hit (afind (r \ <r = stm && <>r = kc) (ktab ()))
                   (two? hit ? (do-act (hit 2) sh lays hist)
                      (loop sh lays hist)))
                (code = 34)                                                      ; MappingNotify: the keyboard/modifier map changed under us
                (ev-raw e 4 @ rq                                          ; (a replug, setxkbmap, xmodmap) -- stale keycodes would
                   (rq @ 2 (loop sh lays hist)                                ; leave every grab dead; pointer mapping (2) is not ours
                    (: _ (x-ungrabkeys s root)
                       tab (keys-resolve ()) (pin ktabc 0 tab, keys-grab tab,
                                              line ("lux: mapping changed -- regrabbed " + show #tab),
                                              loop sh lays hist))))
                (rr && (code = <>rr || code = <>rr + 1))                 ; RRScreenChangeNotify / RRNotify: the monitors moved
                (: _ (line ("lux: randr notify " + show code)) sh2 (rescreen sh)
                   (sh2 = sh ? (loop sh lays hist) (render sh2 lays, loop sh2 lays hist)))
                (code = 22)                                              ; ConfigureNotify: the root's is randr reshaping the screen
                (: pkt (ev-raw e) r [0 0 (u16 pkt 20) (u16 pkt 22)]      ; (a rotation, a mode, a hotplug); a child's is noise
                   (win = root && r != scrn () ?
                      (: _ (pin scrc 0 r) _ (line ("lux: screen " + show (r 2) + "x" + show (r 3)))
                         sh2 (rescreen sh)
                         (render sh2 lays, loop sh2 lays hist))
                      (loop sh lays hist)))
                (code = 28)                                              ; PropertyNotify (window@4, atom@8): a panel changing outputs
                (: pkt (ev-raw e) w (u32 pkt 4) a (u32 pkt 8)             ; rewrites its strut in place, never remapping
                   (a = ewmh-atom "_NET_WM_STRUT_PARTIAL" || a = ewmh-atom "_NET_WM_STRUT" ?
                      (ewmh-untrack w, ewmh-track s w, render sh lays, loop sh lays hist)
                      (loop sh lays hist)))
                (code = 23)                                              ; ConfigureRequest: tiled -> the layout answers, and the
                (? (wsknownw? sh win && !(wsfloating? sh win))           ; client is told so -- a synthetic ConfigureNotify with the
                   (render sh lays, tell! win, x-flush s,        ; real geometry (silence leaves VTE drawing a phantom grid)
                    loop sh lays hist)
                   (: pkt (ev-raw e) mask (u16 pkt 26) g (geom win)       ; unmanaged (pre-map): grant it -- a client waits on
                      gx (mask & 1 ? (u16 pkt 16) (g 0))                   ; this configure before mapping (deny = no MapRequest,
                      gy (mask & 2 ? (u16 pkt 18) (g 1))                   ; the 1x1 deadlock); fields absent from the value-mask
                      gw (mask & 4 ? (u16 pkt 20) (g 2))                   ; keep their current geometry
                      gh (mask & 8 ? (u16 pkt 22) (g 3))
                      _ (move! win gx gy gw gh) _ (x-flush s)
                      sh2 (wsfloating? sh win ? (wsdofloat sh win [gx gy gw gh]) sh)    ; a float's request is granted too, and the
                      (loop sh2 lays hist)))                                      ; sheaf's rect follows it (xmonad: grant + re-float)
                (code = 33)                                                      ; ClientMessage: EWMH requests ride SendEvent to the root
                (: pkt (ev-raw e) cw (ewmh-cm-win pkt) ty (ewmh-cm-type pkt)
                   (fs? d) (d = ewmh-atom "_NET_WM_STATE_FULLSCREEN")
                   (mx? d) (d = ewmh-atom "_NET_WM_STATE_MAXIMIZED_VERT" ||     ; either maximize axis reads as "maximize"
                            d = ewmh-atom "_NET_WM_STATE_MAXIMIZED_HORZ")
                   (screen-of w) (wsscreenof sh w @ r (r ? r (cur-rect sh)))    ; the screen w is on (the current one when hidden)
                   (state-toggle rect atoms word)                               ; _net_wm_state add/remove/toggle -> float at rect / sink
                     (: act (ewmh-cm-d0 pkt)                                    ; on: floated BY this state (our stamp), so a float
                        on (wsfloating? sh cw && any (= <atoms) (x-getprop-atoms s cw (ewmh-atom "_NET_WM_STATE")))   ; the manageHook made shrugs off a remove
                        want (act @ 1 1 0 0 !on)             ; 0 remove / 1 add / 2 toggle
                        (? (want = !!on) (loop sh lays hist)
                           want (wsdofloat (wsmap sh (zfocto cw)) cw rect @ sh2
                                   (x-chprop32 s cw (ewmh-atom "_NET_WM_STATE") 4 atoms,
                                    render sh2 lays, refocus sh2,
                                    line ("lux: " + word + " " + show cw), loop sh2 lays hist))
                           (wssink sh cw @ sh2
                              (x-chprop32 s cw (ewmh-atom "_NET_WM_STATE") 4 (),
                               render sh2 lays, line ("lux: un" + word + " " + show cw), loop sh2 lays hist))))
                   (? (ty = ewmh-atom "_NET_WM_STATE" &&                       ; _net_wm_state add/remove/toggle fullscreen (ewmhFullscreen)
                          wsknownw? sh cw && (fs? (ewmh-cm-d1 pkt) || fs? (ewmh-cm-d2 pkt)))
                      (state-toggle (screen-of cw) [(ewmh-atom "_NET_WM_STATE_FULLSCREEN")] "fullscreen")    ; over its whole screen, struts and all
                      (ty = ewmh-atom "_NET_WM_STATE" &&                       ; maximized_vert/horz -> float over the tiling rect (panel kept)
                          wsknownw? sh cw && (mx? (ewmh-cm-d1 pkt) || mx? (ewmh-cm-d2 pkt)))
                      (state-toggle (trect-of (screen-of cw)) [(ewmh-atom "_NET_WM_STATE_MAXIMIZED_VERT") (ewmh-atom "_NET_WM_STATE_MAXIMIZED_HORZ")] "maximize")
                      (ty = ewmh-atom "WM_CHANGE_STATE" && ewmh-cm-d0 pkt = 3)       ; ICCCM iconify -> minimize (minimizeEventHook)
                      (lays-send lays (wstagof sh cw) ['minimize-window cw] (wstilez sh) @ lays2
                         (render sh lays2, line ("lux: minimize " + show cw), loop sh lays2 hist))
                      (ty = ewmh-atom "_NET_CLOSE_WINDOW" && wsknownw? sh cw)         ; a panel/pager closes a window -- gracefully if it can
                      (x-has-atom s cw "WM_PROTOCOLS" "WM_DELETE_WINDOW" ? (x-wmdel s cw) (x-kill s cw),
                       x-flush s, line ("lux: close " + show cw), loop sh lays hist)
                      (ty = ewmh-atom "_NET_CURRENT_DESKTOP")                    ; a pager switches the desktop -- the same ending, and
                      (relay (switch sh lays (ewmh-cm-d0 pkt + 1)) lays)
                      (ty = ewmh-atom "_NET_WM_DESKTOP")                         ; a pager drags a window to another desktop (W.shiftWin)
                      (: t (ewmh-cm-d0 pkt + 1) sh2 (shiftwin sh cw t)
                         (sh2 = sh ? (loop sh lays hist)                        ; unknown window/tag (or sticky 0xffffffff): a no-op
                          (render sh2 lays,                                   ; arriving on the current view: render maps it...
                           wsvisible? sh2 t ? 0 (hide! cw, x-flush s),       ; ...leaving every screen: hide the emigrant
                           line ("lux: sent " + show cw + " -> " + show t),
                           loop sh2 lays hist)))
                      (ty = ewmh-atom "_NET_ACTIVE_WINDOW")                      ; activate: restore if minimized, view its tag, focus it.
                      (: t (wstagof sh cw)                                       ; source 1 is the app asking for itself, 2 a
                         lays2 (lays-send lays (t ? t (wscur sh)) ['restore-window cw] (wstilez sh))   ; pager (the user): an app may take the keyboard on this
                         (? !t (render sh lays2, loop sh lays2 hist)               ; view but may not drag the view to itself -- a qt modal
                            (ewmh-cm-d0 pkt = 1 && t != wscur sh)                ; re-asserts its activation whenever focus moves, and
                            (line ("lux: activate refused " + show cw), loop sh lays hist)    ; would undo every switch away
                            (relay (wsmap (switch sh lays2 t) (zfocto cw)) lays2)))
                      (loop sh lays hist)))
                (loop sh lays hist)))))

   ; adopt the windows already mapped before we grabbed the redirect (closes the startup race; survives a restart-in-place)
   (furniture? w) (x-has-atom s w "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DESKTOP" ||     ; desktops and docks are furniture, never clients
                      x-has-atom s w "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DOCK")
   (ghostly? w) (two? (x-getprop-atoms s w (x-intern s "WM_STATE")))             ; the last generation's stamp: managed then, maybe hidden now
   ; the race knob, test-only: milliseconds to wait before the sweep reads the
   ; tree. this sweep is the only adoption path for an already-mapped window --
   ; no MapRequest ever comes for one -- and it is one-shot, so losing the race
   ; loses the window for the life of the process. the window is narrower than a
   ; single added comment line's worth of compile time on a cold boot, which is
   ; why every in-process instrument hid it and no candidate fix could be tested.
   ; lux_sweep_delay opens it on demand, so a fix can be measured instead of
   ; guessed. unset in every normal run, where it costs one getenv.
   sweep-wait (: v (getenv "LUX_SWEEP_DELAY") w (0 < #v ? (gem v) 0)
                  (w && 0 < w ? w 0))
   _ (0 < sweep-wait ? (line ("lux: sweep delayed " + show sweep-wait), rest sweep-wait))
   ; one query, and its presence checked: () is a failed round trip, not an empty
   ; root (x-querytree's wrapper). the two reads below used to be two separate
   ; QueryTrees, which could disagree; one answer serves both.
   tree (x-querytree s root)
   _ (atom? tree ?  (line "lux: QueryTree FAILED at startup -- the stream is garbled, adopting nothing"))
   ; and the fault injector, the knob that actually makes a fix testable.
   ; lux_sweep_miss=1 forces the sweep to see an empty tree -- exactly what a lost
   ; race leaves behind. it is the deterministic form of the defect: the delay
   ; knob above can only ever make the sweep later, and later always wins, so a
   ; delay can prove the race's direction but can never reproduce it. this can.
   ; any future fix for "a missed sweep is permanent" must make a miss=1 run pass;
   ; today one fails, because nothing ever looks at the tree a second time.
   twins (? ("1" = getenv "LUX_SWEEP_MISS") (line "lux: sweep MISSED (forced)", ())
            (two? tree) <>tree ())
   kids (filter (nil? * furniture?)
                (filter (w \ x-manageable? s w || ghostly? w) twins))
   _ (map (ewmh-track s) twins)                                          ; a pre-existing dock's strut still shrinks the rect
   _ (map (w \ furniture? w ? (x-cwa-events s w 4194304) 0) twins, x-flush s)   ; and follows the dock's later moves (PropertyChange)
   (adopt-tag w) (: d (x-getprop-atoms s w (x-intern s "_NET_WM_DESKTOP"))       ; the last generation wrote each window's tag on the window
                    t (two? d ? (1 + <d) 1)                                    ; (floats wear their HOME tag too, so they come back to it,
                    (0 < t && #lux-tags >= t ? t 1))                 ; tiled; out of range -> tag 1)
   ; admit a batch: tag it, stamp it ICCCM, wire its mouse, seed the map ledger.
   ; spelled once because the second look below needs exactly the same thing.
   (take-in sh ws)
    (foldl (ss \ w \ wsview (admit (wsview ss (adopt-tag w)) w) <lux-tags) sh ws @ sh2
       (map (w \ x-chprop32 s w (x-intern s "WM_STATE") (x-intern s "WM_STATE") '(1 0)) ws,
        map watch ws,                                                 ; survivors get the mouse wires too
        map (w \ x-manageable? s w ? (pin mapd w 1) 0) ws,                   ; the viewable adoptees are mapped
        map (w \ frame! w (x-getgeom s w)) ws,
        sh2))
   (settle sh ws tag)                                                           ; paint a batch and say so
    (render sh (),
     map (w \ any (= w) (wsonscreen sh) ? 0 (hide! w)) (wstiled sh),        ; adopted onto a hidden tag: hide it
     x-flush s,                                                                 ; now, or it lingers painted over workspace 1 (the WM_STATE
     refocus sh, line (tag + show ws))                                          ; stamp keeps it adoptable through the next restart)
   sh0 (take-in (rescreen (sheaf lux-tags)) kids)                            ; the screens, before any window lands
   _ (two? kids ? (settle sh0 kids "lux: adopted "))
   ; the second look, and the whole point of it: the sweep above is one shot and
   ; it is the only adoption path an already-mapped window has -- no MapRequest
   ; ever comes for one -- so a sweep that read the tree before the server settled
   ; lost those windows for the life OF the process. that is not a rare shape: it
   ; is what a restart-in-place leaves behind, and it presented as a wm that came
   ; back with an empty client list and no way to recover but another restart.
   ; so look again, and keep looking while looking keeps paying -- convergent, not
   ; a magic constant: the pass stops the moment it finds nothing new, so a healthy
   ; start costs one beat and a QueryTree, while a slow server gets several. a
   ; window that arrives after the last pass still has MapRequest; this is only for
   ; the ones that were already mapped when we took over.
   (adoptable sh ws) (filter (w \ !(wsknownw? sh w) &&
                                  !(furniture? w) &&
                                  (x-manageable? s w || ghostly? w)) ws)
   (resweep sh n)
    (n < 1 ? sh
       (: _ (rest 40)
          t2 (x-querytree s root)
          fresh (two? t2 ? (adoptable sh <>t2) ())                             ; a failed query adds nothing
          (? !(two? fresh) sh
             (take-in sh fresh @ sh2
                (map (ewmh-track s) fresh,
                 settle sh2 fresh "lux: adopted late ",
                 resweep sh2 (n - 1))))))
   sh1 (resweep sh0 4)
   _ (twirl (u \ lux-moor (lux-sock ())) 0)                                   ; the repl moor: its own task, its own sockets
   _ (loop sh1 () () ())
   _ (close s)
   _ (line "lux: done")
   (quit 0))                                                                    ; the shebang's -l makes this file a preload: falling off
                                                                                ; the end lands in cli's stdin shell and the process never
                                                                                ; exits, so `exec lux` outlives the wm and the session hangs
