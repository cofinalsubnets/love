; wm/wm.l -- the driver: wire the pure core (wm/core.l) and the X protocol
; (wm/wire.l) into a running window manager. Concatenate them:
;   cat wm/core.l wm/layout.l wm/wire.l wm/manage.l wm/wm.l | ai   (against `Xephyr :7 -ac`)
; This is the scaffold's proof that the modular split composes -- rungs 1-5 of the
; spike (manage/tile/focus/keyboard) plus workspaces (rung 6, clean this time: no
; single-`:` name collisions, because the WM vocabulary lives in core.l/wire.l and
; never shadows a nif). Tall is inlined here for now; layout.l lifts it out later.
; The bindings are a scaffold subset of the target config (mod = super/mod4):
;   mod+j / mod+k  focus down/up      mod+Return  focused -> master
;   mod+1..9       view workspace      mod+shift+1..9  send focused there
(: s (x-connect "/tmp/.X11-unix/X7")
   _ (? s 0 (: _ (say err "wm: no display :7 -- Xephyr up?\n") (nap 1)))
   (line m) (: _ (say out m) _ (say out "\n") (flush out))
   sc (x-setup s)
   _ (? sc 0 (: _ (say err "wm: setup refused\n") (nap 1)))
   root (scr-root sc) wpx (scr-w sc) hpx (scr-h sc)
   _ (? (x-redirect s root) 0 (: _ (say err "wm: another WM owns :7\n") (nap 1)))
   _ (line (+ "wm: managing " (+ (show root) (+ " " (+ (show wpx) (+ "x" (show hpx)))))))

   ; --- keyboard: locate keycodes, grab mod4 + the digits (plain and shifted) ---
   mod (<< 1 6)                                                                  ; mod4 = super = 0x40
   km (x-keymap s (scr-mink sc) (scr-maxk sc) '(106 107 65293 32 44 46 102 109 116 119 49 50 51 52 53 54 55 56 57))
   kj (peep km 106 0) kk (peep km 107 0) kret (peep km 65293 0)
   ksp (peep km 32 0) kcomma (peep km 44 0) kperiod (peep km 46 0)              ; space=NextLayout, ,/.=IncMaster / shift+,/.=Shrink/Expand
   kf (peep km 102 0) kmm (peep km 109 0) kt (peep km 116 0) kw (peep km 119 0) ; f=ToggleLayout(Full), m=MIRROR, t=sink all, w=float focused
   digits (map (\ d (L d (peep km (+ 48 d) 0))) (map (+ 1) (jot 9)))            ; ((tag keycode)..), tags 1..9
   _ (map (\ p (: kc (caup p) _ (x-grab s root mod kc) (x-grab s root (| mod 1) kc))) digits)
   _ (map (\ kc (x-grab s root mod kc)) (L kj kk kret ksp kf kmm kt kw))
   _ (map (\ kc (: _ (x-grab s root mod kc) (x-grab s root (| mod 1) kc))) (L kcomma kperiod))
   _ (x-flush s)
   _ (line "wm: grabbed mod+{j,k,ret,space,comma,period,f,m,t,w,1..9} and mod+shift+{comma,period,1..9}")

   ; --- the layout engine (wm/layout.l) renders the current workspace ---
   (nth l i) (? (< i 1) (cap l) (nth (cup l) (- i 1)))
   defb 3                                                                        ; the config's border-width; a layout may override per-window (a 6th field)
   (render sh lay)                                                               ; ask the layout for placements, configure them, unmap the dropped
    (: z (wsget sh (wscur sh)) rect (L 0 0 wpx hpx)
       pls (cap (lay-tile lay rect z)) placed (map cap pls)
       _ (map (\ t (: _ (x-border s (nth t 0) (? (< (tally t) 6) defb (nth t 5)))   ; smartBorders sets 0 on a singleton/fullscreen
                       (x-configure s (nth t 0) (nth t 1) (nth t 2) (nth t 3) (nth t 4)))) pls)
       _ (map (\ w (? (any (\ p (= p w)) placed) 0 (x-unmap s w))) (wsrow sh))   ; windows the layout dropped (Full/minimize): hide them
       _ (map (\ w (x-map s w)) placed)                                          ; (re)map placed -- a no-op on the already-mapped
       _ (map (\ fp (: w (cap fp) fr (caup fp)                                   ; floating windows: place at their rect, map, raise above the tiles
                        _ (x-border s w defb) _ (x-configure s w (nth fr 0) (nth fr 1) (nth fr 2) (nth fr 3))
                        _ (x-map s w) (x-raise s w))) (wsfloat sh))
       (x-flush s))
   (refocus sh) (? (wsfoc sh) (: _ (x-focus s (wsfoc sh)) (x-flush s)) 0)        ; focus the current top -- only when it is mapped/viewable
   (switch sh lay t)                                                             ; view: hide the leaving row, show the arriving
    (? (|| (= t (wscur sh)) (! (wsknown? sh t))) sh
       (: old (wsrow sh) sh2 (wsview sh t)
          _ (map (\ w (x-map s w)) (wsrow sh2))
          _ (render sh2 lay)
          _ (map (\ w (x-unmap s w)) old) _ (x-flush s)
          _ (line (+ "wm: view " (+ (show t) (+ " " (show (wsrow sh2))))))
          sh2))

   ; --- the event loop: (sheaf, layout, live?) ---
   (loop sh lay live)
    (: e (x-next s)
       (? (! e) (line "wm: display gone")
          (= (ev-code e) 0) (: _ (line (+ "wm: X error " (show (ev-detail e)))) (loop sh lay live))
          (: code (ev-code e) win (ev-window e)
             (? (= code 20)                                                      ; MapRequest: admit tiled, run the manageHook, then place
                (: sh1 (admit sh win)
                   c (mg-ctx s win (L 0 0 wpx hpx) (x-getgeom s win))
                   sh2 (manage-window manage-default c sh1)
                   (? (wsknownw? sh2 win)                                        ; managed (tiled or floated) -> place it
                      (: _ (render sh2 lay) _ (x-map s win) _ (x-flush s)
                         _ (line (+ "wm: + " (+ (show win) (+ " " (show (wsrow sh2)))))) (loop sh2 lay 1))
                      (: _ (x-map s win) _ (x-raise s win) _ (x-flush s)         ; ignored (dock/notification): map raw, on top
                         _ (line (+ "wm: ignore " (show win))) (loop sh2 lay live))))
                (= code 19) (: _ (? (= win (wsfoc sh)) (: _ (x-focus s win) (x-flush s)) 0) (loop sh lay live))   ; MapNotify: focus if it's the top
                (= code 17)                                                      ; DestroyNotify: unmanage + tile
                (: (? (! (wsknownw? sh win)) (loop sh lay live)
                      (: sh2 (evict sh win) _ (render sh2 lay)
                         _ (line (+ "wm: - " (+ (show win) (+ " " (show (wsrow sh2))))))
                         (? (&& live (! (wswins sh2))) (line "wm: empty -- down") (loop sh2 lay live)))))
                (= code 2)                                                       ; KeyPress: drive the core / message the layout
                (: kc (ev-detail e) st (ev-state e) shifted (& st 1) z (wsget sh (wscur sh))
                   (? (= kc kj) (: sh2 (wsmap sh zfocdn) _ (render sh2 lay) _ (refocus sh2) (loop sh2 lay live))
                      (= kc kk) (: sh2 (wsmap sh zfocup) _ (render sh2 lay) _ (refocus sh2) (loop sh2 lay live))
                      (= kc kret) (: sh2 (wsmap sh zmaster) _ (render sh2 lay) _ (refocus sh2) (loop sh2 lay live))
                      (= kc ksp) (: lay2 (msg-or lay (lay-msg lay 'next-layout z)) _ (render sh lay2) _ (refocus sh)
                                    _ (line "wm: next-layout") (loop sh lay2 live))
                      (= kc kcomma) (: lay2 (msg-or lay (lay-msg lay (? shifted 'shrink 'inc-master) z)) _ (render sh lay2) _ (refocus sh) (loop sh lay2 live))
                      (= kc kperiod) (: lay2 (msg-or lay (lay-msg lay (? shifted 'expand 'dec-master) z)) _ (render sh lay2) _ (refocus sh) (loop sh lay2 live))
                      (= kc kf) (: lay2 (msg-or lay (lay-msg lay 'toggle-layout z)) _ (render sh lay2) _ (refocus sh) _ (line "wm: toggle Full") (loop sh lay2 live))
                      (= kc kmm) (: lay2 (msg-or lay (lay-msg lay 'mirror z)) _ (render sh lay2) _ (refocus sh) _ (line "wm: toggle MIRROR") (loop sh lay2 live))
                      (= kc kw) (: fw (wsfoc sh) sh2 (? fw (wsdofloat sh fw (x-getgeom s fw)) sh)   ; float the focused tiled window at its geometry
                                   _ (render sh2 lay) _ (line (+ "wm: float " (show fw))) (loop sh2 lay live))
                      (= kc kt) (: sh2 (foldl (\ ss p (wssink ss (cap p))) sh (wsfloat sh))         ; sink every floating window back to the tiles
                                   _ (render sh2 lay) _ (refocus sh2) _ (line "wm: sink floats") (loop sh2 lay live))
                      (: hit (afind (\ p (= (caup p) kc)) digits)
                         (? (! (two? hit)) (loop sh lay live)
                            (: t (cap hit)
                               (? shifted (: sh2 (shiftto sh t) _ (render sh2 lay)
                                             _ (line (+ "wm: sent -> " (show t))) (loop sh2 lay live))
                                  (loop (switch sh lay t) lay live)))))))
                (= code 23) (: _ (? (wsknownw? sh win) (render sh lay) 0) (loop sh lay live))   ; ConfigureRequest: the layout answers
                (loop sh lay live)))))
   (msg-or old new) (? new new old)                                             ; keep the old layout when a message is unhandled (())
   ; ws 1..9; layout = the config's t (l1 ||| l2): minimize . smartBorders . toggleLayouts Full . MIRROR $ (ResizableTall ||| Dwindle)
   lay0 (minimize (smart-borders (toggle-full (mirror (choice (L (resizable-tall 1 0.02 0.5) (dwindle 1.618)))))))
   ; adopt the windows already mapped before we grabbed the redirect (closes the startup race; survives a restart-in-place)
   kids (filter (\ w (x-manageable? s w)) (x-querytree s root))
   sh0 (foldl (\ ss w (admit ss w)) (sheaf (map (+ 1) (jot 9))) kids)
   _ (? (two? kids) (: _ (render sh0 lay0) _ (refocus sh0) (line (+ "wm: adopted " (show kids)))) 0)
   _ (loop sh0 lay0 (? (two? kids) 1 0))
   _ (close s)
   (line "wm: done"))
