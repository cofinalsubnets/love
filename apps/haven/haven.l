; apps/haven/haven.l -- haven, the wayland compositor: a shore the clients
; moor at. speaks wl_shm / wl_compositor / xdg_wm_base / wl_output, TILES
; its toplevels with the wm's pure layout math (apps/wm/layout.l over the
; focus zipper -- new toplevel takes the master column, xmonad's way), and
; composites every committed buffer into its tile in haven's own X window
; (the pier's blit lane: px-ship over apps/wm/wire.l). a wayland client
; draws, the layout places, and X shows it. loads after apps/wm/{core,
; wire,layout}.l + apps/quay/pier.l + apps/haven/wire.l:
;
;   ai -l apps/wm/core.l -l apps/wm/wire.l -l apps/wm/layout.l \
;      -l apps/quay/pier.l -l apps/haven/wire.l -l apps/haven/haven.l \
;      -e '(haven "/run/user/1000/haven-0" () () 800 600)'
;
; the harbor book hb: 0 the zipper, 1 the layout, 2 the next toplevel key,
; 3 a zero row (the fb wipe), 4 the configure serial. tl maps a key to
; (port toplevel-id xdgsurf-id surface-id rect) -- the roster.
;
; a body-LESS `:` -- the helpers leak; none shadows a nif.
(:
   ; --- the registry: (name interface version kind), what get_registry sings ---
   hv-globals '((1 "wl_shm" 1 shm) (2 "wl_compositor" 4 compositor)
                (3 "xdg_wm_base" 2 wmbase) (4 "wl_output" 2 output))
   (hv-kind nm) (: (go l) (? (two? l)
                             (? (= nm (cap (cap l))) (nthl (cap l) 3) (go (cup l)))
                             ())
                   (go hv-globals))

   ; --- the compositor's one move: a committed buffer lands in its TILE,
   ;     row by row off the client's mapping, clipped to the rect, and the
   ;     band ships. x = (s win gc depth wpx hpx); rect () takes the whole
   ;     glass (a client with no toplevel yet) ---
   (hv-blit x fb buf pool rect)
     (: s (nthl x 0) win (nthl x 1) gc (nthl x 2) depth (nthl x 3)
        fbw (nthl x 4) fbh (nthl x 5)
        r (? (two? rect) rect (rct 0 0 fbw fbh))
        boff (nthl buf 2) w (nthl buf 3) h (nthl buf 4) stride (nthl buf 5)
        ptr (nthl pool 1)
        rows (mn2 h (rh r)) cols (mn2 w (rw r))
        bytes (* cols 4) rowb (* fbw 4)
        (go y) (? (< y rows)
                  (: _ (mapin fb (+ (* (+ (ry r) y) rowb) (* (rx r) 4))
                              ptr (+ boff (* y stride)) bytes)
                     (go (+ y 1)))
                  0)
        _ (? (< 0 ptr) (go 0) 0)
        (px-ship s win gc depth fb fbw (ry r) rows))

   ; --- retile: the layout places the row, every toplevel hears its new
   ;     size, the glass wipes clean (each client recommits into its tile) ---
   (hv-retile hb tl x fb)
     (: res (lay-tile (peep hb 1 ()) (rct 0 0 (nthl x 4) (nthl x 5)) (peep hb 0 ()))
        pls (cap res)
        _ (pin hb 1 (caup res))
        rowb (* (nthl x 4) 4) zr (peep hb 3 ())
        (wipe y) (? (< y (nthl x 5)) (: _ (pour fb (* y rowb) zr 0 rowb) (wipe (+ y 1))) 0)
        _ (wipe 0)
        _ (px-ship (nthl x 0) (nthl x 1) (nthl x 2) (nthl x 3) fb (nthl x 4) 0 (nthl x 5))
        (map (\ p (: key (cap p) e (peep tl key ())
                     (? (! (two? e)) 0
                        (: c (cap e)
                           _ (pin tl key (L c (nthl e 1) (nthl e 2) (nthl e 3) (cup p)))
                           _ (wl-ship c (nthl e 1) 0 (L (nthl p 3) (nthl p 4) 0) ())
                           srl (peep hb 4 1)
                           _ (pin hb 4 (+ srl 1))
                           (wl-ship c (nthl e 2) 0 (L srl) ())))))
             pls))

   ; --- a parting client: its toplevels leave the row, the rest re-place ---
   (hv-farewell c hb tl x fb)
     (: mine (filter (\ key (: e (peep tl key ()) (? (two? e) (= c (cap e)) 0)))
                     (zrow (peep hb 0 ())))
        _ (map (\ key (: _ (pin hb 0 (zdel key (peep hb 0 ()))) (pin tl key ()))) mine)
        (? (two? mine) (hv-retile hb tl x fb) 0))

   ; --- one request. ob keeps the client's objects (id -> (kind ..)); st the
   ;     seam; k the carry the offsets index; hb/tl the shared harbor ---
   (hv-on c st ob k x fb hb tl obj op off sz)
     (: rec (peep ob obj ())
        kind (? (two? rec) (cap rec) (? (= obj 1) 'display ()))
        (? (= kind 'display)
             (? (= op 0) (: cb (wl-u32 k off)             ; sync: done, then let go
                            _ (wl-ship c cb 0 (L 0) ())
                            (wl-ship c 1 1 (L cb) ()))
                (= op 1) (: rid (wl-u32 k off)            ; get_registry: the globals
                            _ (pin ob rid (L 'registry))
                            (map (\ g (wl-ship c rid 0
                                        (link (cap g) (cat (wl-strw (nthl g 1)) (L (nthl g 2))))
                                        ()))
                                 hv-globals))
                0)
           (= kind 'registry)                             ; bind: kind by name
             (: nm (wl-u32 k off)
                vo (wl-rskip k (+ off 4))
                nid (wl-u32 k (+ vo 4))
                kd (hv-kind nm)
                _ (pin ob nid (L kd))
                (? (= kd 'shm)                            ; the formats: argb, xrgb
                   (: _ (wl-ship c nid 0 (L 0) ()) (wl-ship c nid 0 (L 1) ()))
                   0))
           (= kind 'compositor)                           ; create_surface
             (? (= op 0) (pin ob (wl-u32 k off) (L 'surface 0 0 ())) 0)
           (= kind 'shm)                                  ; create_pool: the fd docks
             (? (= op 0) (: nid (wl-u32 k off) size (wl-i32 k (+ off 4))
                            fd (wl-popfd st)
                            ptr (? (< fd 0) 0 (mapfd fd size))
                            (pin ob nid (L 'pool ptr size fd)))
                0)
           (= kind 'pool)                                 ; create_buffer
             (? (= op 0) (pin ob (wl-u32 k off)
                              (L 'buffer obj (wl-i32 k (+ off 4)) (wl-i32 k (+ off 8))
                                 (wl-i32 k (+ off 12)) (wl-i32 k (+ off 16))))
                0)
           (= kind 'surface)                              ; (surface pending cbid key)
             (? (= op 1) (pin ob obj (L 'surface (wl-u32 k off) (nthl rec 2) (nthl rec 3)))
                (= op 3) (pin ob obj (L 'surface (nthl rec 1) (wl-u32 k off) (nthl rec 3)))
                (= op 6) (: pend (nthl rec 1) cb (nthl rec 2) key (nthl rec 3)
                            _ (? (< 0 pend)
                                 (: buf (peep ob pend ())
                                    pool (peep ob (nthl buf 1) ())
                                    e (? (two? key) () (peep tl key ()))
                                    _ (hv-blit x fb buf pool (? (two? e) (nthl e 4) ()))
                                    (wl-ship c pend 0 () ()))                    ; release
                                 0)
                            _ (? (< 0 cb)
                                 (: _ (wl-ship c cb 0 (L 0) ()) (wl-ship c 1 1 (L cb) ()))
                                 0)
                            (pin ob obj (L 'surface pend 0 key)))
                0)
           (= kind 'wmbase)                               ; get_xdg_surface
             (? (= op 2) (pin ob (wl-u32 k off) (L 'xdgsurf (wl-u32 k (+ off 4)))) 0)
           (= kind 'xdgsurf)
             (? (= op 1) (: nid (wl-u32 k off)            ; get_toplevel: join the row
                            surfid (nthl rec 1)
                            key (peep hb 2 1)
                            _ (pin hb 2 (+ key 1))
                            srec (peep ob surfid ())
                            _ (pin ob surfid (L 'surface (nthl srec 1) (nthl srec 2) key))
                            _ (pin ob nid (L 'toplevel key))
                            _ (pin tl key (L c nid obj surfid ()))
                            _ (pin hb 0 (zins key (peep hb 0 ())))
                            (hv-retile hb tl x fb))
                0)
           0))

   ; --- one client, cradle to grave: park, pump, part ---
   (hv-serve c x fb hb tl)
     (: k (cask 65536) sc (cask 65536)
        st (tablet 4) _ (pin st 0 0) _ (pin st 1 ())
        ob (tablet 64)
        (on obj op off sz) (hv-on c st ob k x fb hb tl obj op off sz)
        (drain _) (: r (wl-pump c k sc st on) (? (< 0 r) (drain ()) r))
        (park _) (: _ (await c)
                    r (drain ())
                    (? (< r 0) (park ())
                       (: _ (hv-farewell c hb tl x fb) (close c))))
        (park ()))

   ; --- the harbor: an X window for the glass, a shore for the door ---
   (haven path dpy auth wpx hpx)
     (: s (x-connect dpy)
        (? (! (lit? s)) 'no-socket
         (: sc (x-setup s auth)
            (? (! (two? sc)) (: _ (close s) 'refused)
             (: win (scr-idbase sc) gc (+ 1 (scr-idbase sc)) depth (scr-depth sc)
                _ (px-mkwin s win (scr-root sc) 0 0 wpx hpx)
                _ (px-gc s gc win)
                _ (px-title s win "haven")
                _ (x-map s win)
                _ (x-flush s)
                fb (cask (* wpx (* hpx 4)))
                x (L s win gc depth wpx hpx)
                hb (tablet 8)
                _ (pin hb 0 ()) _ (pin hb 1 (tall 1)) _ (pin hb 2 1)
                _ (pin hb 3 (cask (* wpx 4))) _ (pin hb 4 1)
                tl (tablet 64)
                lp (shore path)
                (? (! (lit? lp)) (: _ (close s) 'no-shore)
                 (: (knock _) (: _ (await lp)
                                 c (accept lp)
                                 _ (? (lit? c) (spin (\ _ (hv-serve c x fb hb tl)) 0) 0)
                                 (knock ()))
                    (knock ())))))))))
