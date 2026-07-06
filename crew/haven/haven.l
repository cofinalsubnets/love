; crew/haven/haven.l -- haven, the wayland compositor: a shore the clients
; moor at. speaks wl_shm / wl_compositor / xdg_wm_base / wl_output, TILES
; its toplevels with phos's pure layout math (crew/phos/layout.l over the
; focus zipper -- new toplevel takes the master column, xmonad's way), and
; composites every committed buffer into its tile in haven's own X window
; (the pier's blit lane: px-ship over crew/phos/wire.l). a wayland client
; draws, the layout places, and X shows it. loads after crew/phos/{core,
; wire,layout}.l + crew/quay/pier.l + crew/haven/wire.l:
;
;   ai -l crew/phos/core.l -l crew/phos/wire.l -l crew/phos/layout.l \
;      -l crew/quay/pier.l -l crew/haven/wire.l -l crew/haven/haven.l \
;      -e '(haven "/run/user/1000/haven-0" () () 800 600)'
;
; the harbor book hb: 0 the zipper, 1 the layout, 2 the next toplevel key,
; 3 a zero row (the fb wipe), 4 the configure serial, 5 the dirty flag (the
; painter task's cue). tl maps a key to (port toplevel-id xdgsurf-id
; surface-id rect) -- the roster.
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
   ;     row by row off the pool's mapping, clipped to the rect. no tile
   ;     (rect ()) draws nowhere -- a toplevel-less surface holds no glass.
   ;     NOBODY here touches X: every mapin is one nif (atomic under the
   ;     vm's fairness yield), and the PAINTER task alone ships the glass
   ;     -- two tasks streaming px-ship on one socket interleave mid-
   ;     PutImage and the server reads pixels as opcodes ---
   (hv-blit x fb buf rect)
     (: rc (nthl buf 1) ptr (peep rc 2 0)
        (? (? (two? rect) (< 0 ptr) 0)
           (: fbw (nthl x 4)
              boff (nthl buf 2) w (nthl buf 3) h (nthl buf 4) stride (nthl buf 5)
              rows (mn2 h (rh rect)) cols (mn2 w (rw rect))
              bytes (* cols 4) rowb (* fbw 4)
              (go y) (? (< y rows)
                        (: _ (mapin fb (+ (* (+ (ry rect) y) rowb) (* (rx rect) 4))
                                    ptr (+ boff (* y stride)) bytes)
                           (go (+ y 1)))
                        0)
              (go 0))
           0))

   ; --- the ledger half of a destructor: the record unpins and the client
   ;     hears delete_id, so the id is truly free to REUSE ---
   (hv-bye c ob obj) (: _ (pin ob obj ()) (wl-ship c 1 1 (L obj) ()))

   ; --- a pool slips its moorings: unmapped, fd closed, exactly once. rc is
   ;     the pool's shared cell -- 0 live buffers, 1 parting, 2 ptr, 3 size,
   ;     4 fd -- so buffers outlive the pool OBJECT (simple-shm's habit) and
   ;     a resize remaps in one place ---
   (hv-slip rc) (: ptr (peep rc 2 0)
                   _ (? (< 0 ptr)
                        (: _ (unmap ptr (peep rc 3 0)) (fdclose (peep rc 4 0)))
                        0)
                   (pin rc 2 0))

   ; --- retile: the layout places the row, every toplevel hears its new
   ;     size, the glass wipes clean (each client recommits into its tile) ---
   (hv-retile hb tl x fb)
     (: res (lay-tile (peep hb 1 ()) (rct 0 0 (nthl x 4) (nthl x 5)) (peep hb 0 ()))
        pls (cap res)
        _ (pin hb 1 (caup res))
        rowb (* (nthl x 4) 4) zr (peep hb 3 ())
        (wipe y) (? (< y (nthl x 5)) (: _ (pour fb (* y rowb) zr 0 rowb) (wipe (+ y 1))) 0)
        _ (wipe 0)
        _ (pin hb 5 1)                                   ; the painter ships it
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
   ;     seam (0 carry fill, 1 fd queue, 2 the client's pool cells); k the
   ;     carry the offsets index; hb/tl the shared harbor ---
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
                vs (wl-u32 k vo)
                nid (wl-u32 k (+ vo 4))
                kd (hv-kind nm)
                _ (pin ob nid (L kd))
                (? (= kd 'shm)                            ; the formats: argb, xrgb
                     (: _ (wl-ship c nid 0 (L 0) ()) (wl-ship c nid 0 (L 1) ()))
                   (= kd 'output)                         ; the glass, sung whole
                     (: _ (wl-ship c nid 0 (cat (L 0 0 0 0 0)
                                           (cat (wl-strw "haven") (cat (wl-strw "glass") (L 0)))) ())
                        _ (wl-ship c nid 1 (L 3 (nthl x 4) (nthl x 5) 60000) ())
                        (? (< vs 2) 0                     ; scale + done arrived at v2
                           (: _ (wl-ship c nid 3 (L 1) ())
                              (wl-ship c nid 2 () ()))))
                   0))
           (= kind 'compositor)                           ; create_surface / create_region
             (? (= op 0) (pin ob (wl-u32 k off) (L 'surface 0 0 ()))
                (= op 1) (pin ob (wl-u32 k off) (L 'region))
                0)
           (= kind 'region)
             (? (= op 0) (hv-bye c ob obj) 0)
           (= kind 'shm)                                  ; create_pool: the fd docks
             (? (= op 0) (: nid (wl-u32 k off) size (wl-i32 k (+ off 4))
                            fd (wl-popfd st)
                            rc (tablet 4)
                            _ (pin rc 0 0) _ (pin rc 1 0)
                            _ (pin rc 2 (? (< fd 0) 0 (mapfd fd size)))
                            _ (pin rc 3 size) _ (pin rc 4 fd)
                            _ (pin st 2 (link rc (peep st 2 ())))
                            (pin ob nid (L 'pool rc)))
                0)
           (= kind 'pool)                                 ; create_buffer / destroy / resize
             (: rc (nthl rec 1)
                (? (= op 0) (: _ (pin rc 0 (+ 1 (peep rc 0 0)))
                               (pin ob (wl-u32 k off)
                                    (L 'buffer rc (wl-i32 k (+ off 4)) (wl-i32 k (+ off 8))
                                       (wl-i32 k (+ off 12)) (wl-i32 k (+ off 16)))))
                   (= op 1) (: _ (? (< 0 (peep rc 0 0)) (pin rc 1 1) (hv-slip rc))   ; buffers still sail: part later
                               (hv-bye c ob obj))
                   (= op 2) (: ns (wl-i32 k off)          ; resize: remap, the buffers follow the cell
                               _ (? (< 0 (peep rc 2 0)) (unmap (peep rc 2 0) (peep rc 3 0)) 0)
                               _ (pin rc 2 (mapfd (peep rc 4 0) ns))
                               (pin rc 3 ns))
                   0))
           (= kind 'buffer)                               ; destroy: the last one slips a parting pool
             (? (= op 0) (: rc (nthl rec 1)
                            n (- (peep rc 0 0) 1)
                            _ (pin rc 0 n)
                            _ (? (? (< n 1) (< 0 (peep rc 1 0)) 0) (hv-slip rc) 0)
                            (hv-bye c ob obj))
                0)
           (= kind 'surface)                              ; (surface pending cbid key)
             (? (= op 0) (hv-bye c ob obj)
                (= op 1) (pin ob obj (L 'surface (wl-u32 k off) (nthl rec 2) (nthl rec 3)))
                (= op 3) (pin ob obj (L 'surface (nthl rec 1) (wl-u32 k off) (nthl rec 3)))
                (= op 6) (: pend (nthl rec 1) cb (nthl rec 2) key (nthl rec 3)
                            _ (? (< 0 pend)
                                 (: buf (peep ob pend ())
                                    e (? key (peep tl key ()) ())
                                    _ (? (two? buf)
                                         (: _ (hv-blit x fb buf (? (two? e) (nthl e 4) ()))
                                            (pin hb 5 1))
                                         0)
                                    (wl-ship c pend 0 () ()))                    ; release
                                 0)
                            _ (? (< 0 cb)
                                 (: _ (wl-ship c cb 0 (L 0) ()) (wl-ship c 1 1 (L cb) ()))
                                 0)
                            (pin ob obj (L 'surface 0 0 key)))     ; commit CONSUMES: one release per attach
                0)
           (= kind 'wmbase)                               ; destroy / positioner / get_xdg_surface
             (? (= op 0) (hv-bye c ob obj)
                (= op 1) (pin ob (wl-u32 k off) (L 'positioner))
                (= op 2) (pin ob (wl-u32 k off) (L 'xdgsurf (wl-u32 k (+ off 4))))
                0)
           (= kind 'positioner)
             (? (= op 0) (hv-bye c ob obj) 0)
           (= kind 'xdgsurf)
             (? (= op 0) (hv-bye c ob obj)
                (= op 1) (: nid (wl-u32 k off)            ; get_toplevel: join the row
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
           (= kind 'toplevel)                             ; destroy: leave the row
             (? (= op 0) (: key (nthl rec 1)
                            e (peep tl key ())
                            _ (hv-bye c ob obj)
                            (? (two? e)
                               (: srec (peep ob (nthl e 3) ())
                                  _ (? (two? srec)      ; the surface stays, keyless
                                       (pin ob (nthl e 3) (L 'surface (nthl srec 1) (nthl srec 2) ()))
                                       0)
                                  _ (pin hb 0 (zdel key (peep hb 0 ())))
                                  _ (pin tl key ())
                                  (hv-retile hb tl x fb))
                               0))
                0)
           0))

   ; --- one client, cradle to grave: park, pump, part ---
   (hv-serve c x fb hb tl)
     (: k (cask 65536) sc (cask 65536)
        st (tablet 4) _ (pin st 0 0) _ (pin st 1 ()) _ (pin st 2 ())
        ob (tablet 64)
        (on obj op off sz) (hv-on c st ob k x fb hb tl obj op off sz)
        (drain _) (: r (wl-pump c k sc st on) (? (< 0 r) (drain ()) r))
        (park _) (: _ (await c)
                    r (drain ())
                    (? (< r 0) (park ())
                       (: _ (hv-farewell c hb tl x fb)
                          _ (map hv-slip (peep st 2 ()))   ; every pool slips with its client
                          (close c))))
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
                _ (pin hb 3 (cask (* wpx 4))) _ (pin hb 4 1) _ (pin hb 5 0)
                tl (tablet 64)
                lp (shore path)
                (? (! (lit? lp)) (: _ (close s) 'no-shore)
                 (: ; the painter: the ONE task that writes X post-boot. clients
                    ; mapin + raise the dirty flag; this ships the whole glass on
                    ; an 8ms clock (pier's paintloop discipline -- a second X
                    ; writer would interleave mid-PutImage under the vm's yield)
                    (paint _) (: _ (? (peep hb 5 0)
                                      (: _ (pin hb 5 0)
                                         (px-ship s win gc depth fb wpx 0 hpx))
                                      0)
                                 _ (rest 8)
                                 (paint ()))
                    _ (spin paint 0)
                    (knock _) (: _ (await lp)
                                 c (accept lp)
                                 _ (? (lit? c) (spin (\ _ (hv-serve c x fb hb tl)) 0) 0)
                                 (knock ()))
                    (knock ())))))))))
