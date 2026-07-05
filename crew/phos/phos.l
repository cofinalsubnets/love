; crew/phos/phos.l -- the driver: wire the pure core (crew/phos/core.l), the layout engine
; (crew/phos/layout.l), the manageHook (crew/phos/manage.l), the keymap (crew/phos/keys.l), and EWMH
; (crew/phos/ewmh.l) over the X protocol (crew/phos/wire.l), configured by crew/phos/config.l.
; Concatenate them:
;   cat crew/phos/{core,layout,wire,ewmh,manage,keys,config,phos}.l | ai
; (against `Xephyr :7 -ac`, or a real server with phos-auth set). Rung 8: the
; driver reads the CONFIG -- border width and colors (focused/normal pixels),
; workspaces, the layout stack, hooks, keymap, startup spawns -- and runs until
; the display dies or (quit). The f_t hinge: a float-focused chord moves/
; resizes the float, a tile-focused one messages the layout / navigates. ffoc
; tracks the focused FLOAT (the zipper only holds tiles); hist is nextMatch's
; MRU focus ring.
(: s (x-connect phos-display)
   _ (? s 0 (: _ (say err "phos: no display -- Xephyr up?\n") (nap 1)))
   (line m) (: _ (say out m) _ (say out "\n") (flush out))
   sc (x-setup s phos-auth)
   _ (? sc 0 (: _ (say err "phos: setup refused (auth?)\n") (nap 1)))
   root (scr-root sc) wpx (scr-w sc) hpx (scr-h sc)
   _ (? (x-redirect s root) 0 (: _ (say err "phos: another WM owns this display\n") (nap 1)))
   _ (line (+ "phos: managing " (+ (show root) (+ " " (+ (show wpx) (+ "x" (show hpx)))))))
   _ (ewmh-init s root (scr-idbase sc) (tally phos-tags))                          ; the support window + _NET_* root properties

   ; --- the config's face: border pixels, the root cursor, the startup spawns ---
   npix (x-color s (scr-cmap sc) phos-normal-color)
   fpix (x-color s (scr-cmap sc) phos-focused-color)
   _ (line (+ "phos: colors " (+ (show npix) (+ " " (show fpix)))))
   _ (x-cursor s root (+ (scr-idbase sc) 1) (+ (scr-idbase sc) 2))               ; setDefaultCursor xC_left_ptr
   _ (map (\ cmd (spawn cmd)) phos-startup)

   ; --- keyboard: resolve the keymap's keysyms to keycodes, grab every chord ---
   km (x-keymap s (scr-mink sc) (scr-maxk sc) (keys-syms phos-keymap))
   ktab (filter (\ r (> (caup r) 0))                                             ; rows (mods keycode action); keysym absent -> dropped
                (map (\ r (L (kb-mods r) (peep km (kb-sym r) 0) (kb-act r))) phos-keymap))
   _ (map (\ r (x-grab s root (cap r) (caup r))) ktab)
   _ (x-flush s)
   _ (line (+ "phos: grabbed " (+ (show (tally ktab)) " chords")))

   ; --- rendering (the layout engine answers, X obeys) ---
   (nth l i) (? (< i 1) (cap l) (nth (cup l) (- i 1)))
   scrn (L 0 0 wpx hpx)
   (trect u) (ewmh-rect scrn wpx hpx)                                            ; the tiling rect: screen minus dock struts (sup+b flips)
   (render sh lay)                                                               ; ask the layout for placements, configure them, unmap the dropped
    (: z (wsget sh (wscur sh)) f (zfoc z)
       pls (cap (lay-tile lay (trect ()) z)) placed (map cap pls)
       _ (map (\ t (: w (nth t 0) bw (? (< (tally t) 6) phos-border (nth t 5))   ; smartBorders sets 0 on a singleton/fullscreen
                      _ (x-border s w bw)
                      _ (x-borderpix s w (? (= w f) fpix npix))                  ; focusedBorderColor / normalBorderColor
                      (x-configure s w (nth t 1) (nth t 2)                       ; the border sits OUTSIDE the frame: shave it off
                                   (mx2 1 (- (nth t 3) (* 2 bw))) (mx2 1 (- (nth t 4) (* 2 bw)))))) pls)
       _ (map (\ w (? (any (\ p (= p w)) placed) 0 (x-unmap s w))) (wsrow sh))   ; windows the layout dropped (Full/minimize): hide them
       _ (map (\ w (x-map s w)) placed)                                          ; (re)map placed -- a no-op on the already-mapped
       _ (map (\ fp (: w (cap fp) fr (caup fp)                                   ; floating windows: place at their rect, map, raise above the tiles
                        _ (x-border s w phos-border) _ (x-borderpix s w npix)
                        _ (x-configure s w (nth fr 0) (nth fr 1) (nth fr 2) (nth fr 3))
                        _ (x-map s w) (x-raise s w))) (wsfloat sh))
       (x-flush s))
   (refocus sh) (? (wsfoc sh) (: _ (x-focus s (wsfoc sh)) (x-flush s)) 0)        ; focus the current top -- only when it is mapped/viewable
   (switch sh lay t)                                                             ; view: hide the leaving row, show the arriving
    (? (|| (= t (wscur sh)) (! (wsknown? sh t))) sh
       (: old (wsrow sh) sh2 (wsview sh t)
          _ (map (\ w (x-map s w)) (wsrow sh2))
          _ (render sh2 lay)
          _ (map (\ w (x-unmap s w)) old) _ (x-flush s)
          _ (line (+ "phos: view " (+ (show t) (+ " " (show (wsrow sh2))))))
          sh2))
   (msg-or old new) (? new new old)                                              ; keep the old layout when a message is unhandled (())
   (phos-self u)                                                                   ; our script path, either argv shape: plain `ai phos`
    (: (go m) (? (! (two? m)) (cap argv)                                         ; gives (script ..); the -l shebang gives the RAW OS
                 (= (cap m) "-l") (? (two? (cup m)) (caup m) (cap argv))         ; argv (ai -l script ..) -- take the -l operand
                 (go (cup m)))
       (go argv))

   ; --- do-act: interpret one keys.l action. Returns by looping. ---
   (do-act a sh lay hist ffoc)
    (: k (cap a) z (wsget sh (wscur sh)) fw (? ffoc ffoc (wsfoc sh))
       (relay sh2 lay2 f2) (: _ (render sh2 lay2) _ (refocus sh2) (loop sh2 lay2 hist f2))
       (? (= k 'msg) (relay sh (msg-or lay (lay-msg lay (caup a) z)) ffoc)
          (= k 'focus-dn) (relay (wsmap sh zfocdn) lay ())
          (= k 'focus-up) (relay (wsmap sh zfocup) lay ())
          (= k 'focus-master) (relay (wsmap sh (\ zz (zfocto (? (two? (zrow zz)) (cap (zrow zz)) ()) zz))) lay ())
          (= k 'swap-dn) (relay (wsmap sh zswapdn) lay ffoc)
          (= k 'swap-up) (relay (wsmap sh zswapup) lay ffoc)
          (= k 'swap-master) (relay (wsmap sh zmaster) lay ffoc)
          (= k 'view) (loop (switch sh lay (caup a)) lay hist ffoc)
          (= k 'shift) (: w (wsfoc sh) sh2 (shiftto sh (caup a)) _ (render sh2 lay)
                          _ (? (&& w (! (any (\ x (= x w)) (wsrow sh2))))        ; the emigrant left this workspace: hide it
                               (: _ (x-unmap s w) (x-flush s)) 0)
                          _ (line (+ "phos: sent -> " (show (caup a)))) (loop sh2 lay hist ffoc))
          (= k 'spawn) (: p (spawn (caup a)) _ (line (+ "phos: spawn " (+ (cap (caup a)) (+ " " (show p)))))
                          (loop sh lay hist ffoc))
          (= k 'exec) (: _ (line "phos: exec -- abdicating") _ (exec (caup a))     ; returns only on failure
                         (loop sh lay hist ffoc))
          (= k 'kill) (: _ (? fw (: _ (? (x-has-atom s fw "WM_PROTOCOLS" "WM_DELETE_WINDOW")   ; ask first (killWindow): KillClient
                                         (x-wmdel s fw) (x-kill s fw))           ; takes the whole CLIENT, every window it owns
                                     (x-flush s)) 0)                             ; DestroyNotify does the eviction
                         _ (line (+ "phos: kill " (show fw))) (loop sh lay hist ffoc))
          (= k 'quit) (line "phos: quit")                                          ; fall out of the loop
          (= k 'restart)                                                         ; restart-in-place: exec ourselves (the CLOEXEC'd socket
          (: _ (line (+ "phos: restart -- exec, pid " (show (getpid 0))))          ; drops, the server releases the redirect, the new
             _ (exec (L "/proc/self/exe" (phos-self ())))                          ; generation ADOPTS the surviving windows at startup)
             _ (line "phos: restart failed") (loop sh lay hist ffoc))
          (= k 'refresh) (relay sh lay ffoc)
          (= k 'reset-layout) (relay sh phos-layout ffoc)
          (= k 'toggle-struts) (: _ (ewmh-toggle ()) _ (line "phos: toggle struts") (relay sh lay ffoc))
          (= k 'sink) (? (wsfloating? sh fw) (relay (wssink sh fw) lay ()) (loop sh lay hist ffoc))
          (= k 'float-toggle)
          (? (! fw) (loop sh lay hist ffoc)
             (wsfloating? sh fw) (relay (wssink sh fw) lay ())
             (: _ (line (+ "phos: float " (show fw))) (relay (wsdofloat sh fw (x-getgeom s fw)) lay fw)))
          (= k 'next-match)
          (: t (nm-pick (wsrow sh) (wsfoc sh) hist (caup a))
             (? t (relay (wsmap sh (zfocto t)) lay ()) (loop sh lay hist ffoc)))
          ; --- the directional trio: the f_t hinge ---
          (wsfloating? sh fw)                                                    ; float focused: move (go) or resize (swapd/resize)
          (: r (wsrect sh fw) d (nthl a 2) dx (cap d) dy (caup d)
             r2 (? (= k 'go) (L (+ (nth r 0) dx) (+ (nth r 1) dy) (nth r 2) (nth r 3))
                   (L (nth r 0) (nth r 1) (mx2 20 (+ (nth r 2) dx)) (mx2 20 (+ (nth r 3) dy))))
             (relay (wsdofloat sh fw r2) lay ffoc))
          (: dir (caup a) pls (cap (lay-tile lay (trect ()) z)) tgt (nav-target pls (wsfoc sh) dir)
             (? (= k 'go) (? tgt (relay (wsmap sh (zfocto tgt)) lay ()) (loop sh lay hist ffoc))
                (= k 'swapd) (? tgt (relay (wsmap sh (zswapw (wsfoc sh) tgt)) lay ffoc) (loop sh lay hist ffoc))
                (relay sh (msg-or lay (lay-msg lay (? (|| (= dir 'left) (= dir 'down)) 'shrink 'expand) z)) ffoc)))))

   ; --- the event loop: (sheaf, layout, focus-history, focused-float) ---
   (loop sh lay hist ffoc)
    (: f (wsfoc sh)
       hist (? (&& f (! (= f (? (two? hist) (cap hist) ())))) (link f (znub f hist)) hist)
       _ (reap 0)                                                                ; harvest one spawned zombie, if any
       _ (ewmh-sync s sh)                                                        ; publish the sheaf to pagers (change-guarded)
       e (x-next s)
       (? (! e) (line "phos: display gone")
          (= (ev-code e) 0) (: _ (line (+ "phos: X error " (show (ev-detail e)))) (loop sh lay hist ffoc))
          (: code (ev-code e) win (ev-window e)
             (? (&& (= code 20) (wsknownw? sh win))                              ; MapRequest from a window we already manage: IGNORE it
                (: _ (line (+ "phos: remap " (show win))) (loop sh lay hist ffoc))   ; (mapping it here would paint it OVER a workspace it
                (= code 20)                                                      ; isn't on -- the "one window on two workspaces" bug)
                                                                                 ; MapRequest: admit tiled, run the manageHook, then place
                (: _ (? (ewmh-track s win) (line (+ "phos: strut " (show win))) 0) ; a dock's strut shrinks the tiling rect
                   sh1 (admit sh win)
                   c (mg-ctx s win scrn (x-getgeom s win))
                   sh2 (manage-window phos-manage c sh1)
                   ffoc2 (? (wsfloating? sh2 win) win ffoc)                      ; a hook-floated window takes the float focus
                   (? (wsknownw? sh2 win)                                        ; managed (tiled or floated) -> place it
                      (: _ (x-chprop32 s win (x-intern s "WM_STATE") (x-intern s "WM_STATE") (L 1 0))   ; the ICCCM stamp: a restart finds us even hidden
                         _ (render sh2 lay) _ (x-map s win) _ (x-flush s)
                         _ (line (+ "phos: + " (+ (show win) (+ " " (show (wsrow sh2)))))) (loop sh2 lay hist ffoc2))
                      (: _ (x-map s win)                                         ; ignored: map raw -- a desktop UNDER everything, a dock/notification on top
                         _ (? (x-has-atom s win "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DESKTOP")
                              (x-lower s win) (x-raise s win))
                         _ (x-flush s)
                         _ (line (+ "phos: ignore " (show win))) (loop sh2 lay hist ffoc))))
                (= code 19) (: _ (? (= win (wsfoc sh)) (: _ (x-focus s win) (x-flush s)) 0) (loop sh lay hist ffoc))   ; MapNotify: focus if it's the top
                (= code 17)                                                      ; DestroyNotify: unmanage + tile
                (: _ (ewmh-untrack win)
                   (? (! (wsknownw? sh win)) (loop sh lay hist ffoc)
                      (: sh2 (evict sh win) _ (render sh2 lay)
                         ffoc2 (? (= win ffoc) () ffoc)
                         _ (line (+ "phos: - " (+ (show win) (+ " " (show (wsrow sh2))))))
                         (loop sh2 lay hist ffoc2))))
                (= code 2)                                                       ; KeyPress: the table answers
                (: kc (ev-detail e) stm (& (ev-state e) kmodmask)
                   hit (afind (\ r (&& (= (cap r) stm) (= (caup r) kc))) ktab)
                   (? (two? hit) (do-act (nthl hit 2) sh lay hist ffoc)
                      (loop sh lay hist ffoc)))
                (= code 23)                                                      ; ConfigureRequest: TILED -> the layout answers, and the
                (? (&& (wsknownw? sh win) (! (wsfloating? sh win)))              ; client is TOLD so -- a synthetic ConfigureNotify with the
                   (: _ (render sh lay) _ (x-confnotify s win) _ (x-flush s)     ; real geometry (silence leaves VTE drawing a phantom grid)
                      (loop sh lay hist ffoc))
                   (: pkt (ev-raw e) mask (u16 pkt 26) g (x-getgeom s win)       ; unmanaged (pre-map): GRANT it -- a client WAITS on
                      gx (? (& mask 1) (u16 pkt 16) (nth g 0))                   ; this configure before mapping (deny = no MapRequest,
                      gy (? (& mask 2) (u16 pkt 18) (nth g 1))                   ; the 1x1 deadlock); fields absent from the value-mask
                      gw (? (& mask 4) (u16 pkt 20) (nth g 2))                   ; keep their current geometry
                      gh (? (& mask 8) (u16 pkt 22) (nth g 3))
                      _ (x-configure s win gx gy gw gh) _ (x-flush s)
                      sh2 (? (wsfloating? sh win) (wsdofloat sh win (L gx gy gw gh)) sh)   ; a FLOAT's request is granted too, and the
                      (loop sh2 lay hist ffoc)))                                 ; sheaf's rect follows it (xmonad: grant + re-float)
                (= code 33)                                                      ; ClientMessage: EWMH requests ride SendEvent to the root
                (: pkt (ev-raw e) cw (ewmh-cm-win pkt) ty (ewmh-cm-type pkt)
                   (? (&& (= ty (ewmh-atom "_NET_WM_STATE"))                     ; _NET_WM_STATE add/remove/toggle FULLSCREEN (ewmhFullscreen)
                          (&& (wsknownw? sh cw)
                              (|| (= (ewmh-cm-d1 pkt) (ewmh-atom "_NET_WM_STATE_FULLSCREEN"))
                                  (= (ewmh-cm-d2 pkt) (ewmh-atom "_NET_WM_STATE_FULLSCREEN")))))
                      (: act (ewmh-cm-d0 pkt) on (wsfloating? sh cw)
                         want (? (= act 1) 1 (= act 0) 0 (? on 0 1))             ; 0 remove / 1 add / 2 toggle
                         (? (= want (? on 1 0)) (loop sh lay hist ffoc)
                            want (: sh2 (wsdofloat sh cw scrn)                   ; fullscreen floats at the FULL screen rect (over any strut)
                                    _ (x-chprop32 s cw (ewmh-atom "_NET_WM_STATE") 4 (L (ewmh-atom "_NET_WM_STATE_FULLSCREEN")))
                                    _ (render sh2 lay) _ (line (+ "phos: fullscreen " (show cw))) (loop sh2 lay hist cw))
                            (: sh2 (wssink sh cw)
                               _ (x-chprop32 s cw (ewmh-atom "_NET_WM_STATE") 4 ())
                               _ (render sh2 lay) _ (line (+ "phos: unfullscreen " (show cw))) (loop sh2 lay hist ()))))
                      (&& (= ty (ewmh-atom "WM_CHANGE_STATE")) (= (ewmh-cm-d0 pkt) 3))   ; ICCCM iconify -> minimize (minimizeEventHook)
                      (: lay2 (msg-or lay (lay-msg lay (L 'minimize-window cw) (wsget sh (wscur sh))))
                         _ (render sh lay2) _ (line (+ "phos: minimize " (show cw))) (loop sh lay2 hist ffoc))
                      (= ty (ewmh-atom "_NET_CURRENT_DESKTOP"))                  ; a pager switches the desktop
                      (loop (switch sh lay (+ (ewmh-cm-d0 pkt) 1)) lay hist ffoc)
                      (= ty (ewmh-atom "_NET_ACTIVE_WINDOW"))                    ; a pager activates: restore if minimized, view its tag, focus
                      (: z (wsget sh (wscur sh))
                         lay2 (msg-or lay (lay-msg lay (L 'restore-window cw) z))
                         t (wstagof sh cw)
                         (? (! t) (: _ (render sh lay2) (loop sh lay2 hist ffoc))
                            (: sh2 (wsmap (switch sh lay2 t) (zfocto cw))
                               _ (render sh2 lay2) _ (refocus sh2) (loop sh2 lay2 hist ()))))
                      (loop sh lay hist ffoc)))
                (loop sh lay hist ffoc)))))

   ; adopt the windows already mapped before we grabbed the redirect (closes the startup race; survives a restart-in-place)
   (furniture? w) (|| (x-has-atom s w "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DESKTOP")   ; desktops and docks are furniture, never clients
                      (x-has-atom s w "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DOCK"))
   (ghostly? w) (two? (x-getprop-atoms s w (x-intern s "WM_STATE")))             ; the last generation's stamp: managed then, maybe hidden now
   kids (filter (\ w (! (furniture? w)))
                (filter (\ w (|| (x-manageable? s w) (ghostly? w))) (x-querytree s root)))
   _ (map (\ w (ewmh-track s w)) (x-querytree s root))                           ; a pre-existing dock's strut still shrinks the rect
   (adopt-tag w) (: d (x-getprop-atoms s w (x-intern s "_NET_WM_DESKTOP"))       ; the last generation wrote each window's tag on the window
                    t (? (two? d) (+ 1 (cap d)) 1)
                    (? (&& (< 0 t) (! (< (tally phos-tags) t))) t 1))            ; out of range (a float's sticky marker) -> tag 1
   sh0 (foldl (\ ss w (wsview (admit (wsview ss (adopt-tag w)) w) (cap phos-tags))) (sheaf phos-tags) kids)
   _ (map (\ w (x-chprop32 s w (x-intern s "WM_STATE") (x-intern s "WM_STATE") (L 1 0))) kids)
   _ (? (two? kids) (: _ (render sh0 phos-layout)
                       _ (map (\ w (? (any (\ x (= x w)) (wsrow sh0)) 0 (x-unmap s w))) (wstiled sh0))   ; adopted onto a HIDDEN tag: hide it
                       _ (x-flush s)                                             ; now, or it lingers painted over workspace 1 (the WM_STATE
                       _ (refocus sh0) (line (+ "phos: adopted " (show kids)))) 0)   ; stamp keeps it adoptable through the NEXT restart)
   _ (loop sh0 phos-layout () ())
   _ (close s)
   (line "phos: done"))
