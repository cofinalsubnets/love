; src/apps/lux/manage.l -- the manageHook dsl, after xmonad: the driver tiles a new window
; first, then a hook (ctx sh -> sh) may float, center or evict it. the combinators and
; actions are pure (test/law/lux.l); the predicates query X, so they and the default are
; host-only. a body-less `:`, it all leaks to the driver.
; ctx = (socket window screen-rect win-geom)

; the combinators are operators: `pred -?> act`, `p <||> q`. grip stands in its own form:
; opfix factors a whole form at once, so a row pinned inside the `:` would land too late.
; <||> sits in the logical band with ||, -?> just under it; 2 is the lane (binary infix),
; the band positive for right-handed
(borrow 'xwire)   ; src/apps/lux/wire.l
(grip 2 '<||> 30)
(grip 2 '-?> 25)
(:
   (mg-ctx s win screen geom) [s win screen geom]
   (mg-sock c) (c 0)  (mg-win c) (c 1)  (mg-screen c) (c 2)  (mg-geom c) (c 3)

   ; --- actions: (ctx sh) -> sh; ignore evicts, raise restacks (X) ---
   (do-full-float c sh) (wsdofloat sh (mg-win c) (mg-screen c))
   (do-float c sh) (wsdofloat sh (mg-win c) (mg-geom c))
   (do-center-float c sh)
    (: r (mg-screen c) g (mg-geom c) w (rw g) h (rh g)
       (wsdofloat sh (mg-win c) (rct (rx r + (rw r - w) // 2) (ry r + (rh r - h) // 2) w h)))
   (do-ignore c sh) (evict sh (mg-win c))                                        ; never managed (docks, notifications): the driver maps it raw
   (do-raise c sh) (x-raise (mg-sock c) (mg-win c), sh)                          ; restack above (X); the sheaf unchanged

   ; --- predicates: (ctx) -> bool ---
   (prop? propnm valnm) (c \ x-has-atom (mg-sock c) (mg-win c) propnm valnm)   ; isInProperty atom VALUE
   (class-of? names) (? !(two? names) (c \ 0)                                    ; an empty roster asks X nothing
                        (c \ : cl (x-getclass (mg-sock c) (mg-win c)) (any (= cl) names)))
   (<||> p q) (c \ p c || q c)

   ; --- combinators: a -?> hook answers [sh'] when matched, else (); compose-one takes the
   ;     first match, compose-all threads plain hooks ---
   (-?> pred act) (c \ sh \ (pred c ? [(act c sh)] ()))
   (compose-one mhs) (c \ sh \ (: (go l) (? !(two? l) sh
                                            (<l c sh @ r (two? r ? <r (go >l)))) (go mhs)))
   (compose-all hs) (c \ sh \ foldl (s \ h \ h c s) sh hs)

   ; --- transience' and manageDocks as values, not nullary helpers: (f) == f would hand back
   ;     the wrapper unrun ---
   transience (c \ sh \ (x-transient (mg-sock c) (mg-win c) ? (do-center-float c sh) sh))   ; a dialog floats centered on its parent
   manage-docks (c \ sh \ (? ((prop? "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DOCK"          ; a dock or a desktop (the file
                               <||> prop? "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DESKTOP") c)     ; manager's wallpaper) is a client
                             (do-ignore c sh) sh))                                                  ; only by accident

   (manage-window hook c sh) (hook c sh)

   ; --- class rosters (config.l reads them out of salt), symbols or strings; wm_class is
   ;     text, so spell every entry as text here ---
   (mg-classes ns) (map (n \ name? n ? (string n) n) (filter (n \ name? n || string? n) ns))
   mg-center-def '("Xmessage" "Xscreensaver-settings" "feh" "vlc")               ; dialogs by nature, whatever they say
   mg-float-def  '("steam" "Gimp" "krita")                                       ; toolkits that place their own windows
   mg-panel-def  '("Xfce4-panel")

   ; --- the config's manageHook (host-only: it calls prop? at load) ---
   (manage-for centers floats ignores)
    (compose-all [
       (c \ sh \ sh)                                                            ; tile: the driver already admitted it
       transience
       manage-docks
       (compose-one [
          (class-of? (mg-classes ignores) -?> (c \ sh \ do-ignore c (do-raise c sh)))
          ((prop? "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_NOTIFICATION"
            <||> prop? "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DOCK")
           -?> (c \ sh \ do-ignore c (do-raise c sh)))                          ; doRaise >> doIgnore
          (prop? "_NET_WM_STATE" "_NET_WM_STATE_FULLSCREEN" -?> do-full-float)
          ((prop? "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DIALOG"
            <||> class-of? (mg-classes centers))
           -?> do-center-float)
          ((prop? "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_UTILITY"            ; self-placed popups float: a panel's
            <||> prop? "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_TOOLBAR"       ; calendar, toolboxes, splashes
            <||> prop? "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_SPLASH"
            <||> class-of? (mg-classes mg-panel-def))                            ; the panel itself is a DOCK, ignored above
           -?> do-float)
          ((prop? "_NET_WM_STATE" "_NET_WM_STATE_MODAL"
            <||> class-of? (mg-classes floats))
           -?> do-float)])])
   manage-default (manage-for mg-center-def mg-float-def ()))
