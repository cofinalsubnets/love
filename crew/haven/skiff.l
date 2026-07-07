; crew/haven/skiff.l -- skiff, the little wayland client: rows one solid
; color over to whatever compositor listens at the path. binds the registry,
; raises an xdg toplevel, brushes a memfd pool, attaches + commits -- and
; when the compositor reconfigures it (a retile), it dresses a FRESH pool
; at the new size and recommits: the honest wayland resize dance. loads
; after crew/haven/wire.l.
;
;   ai -l crew/haven/wire.l -l crew/haven/skiff.l \
;      -e '(skiff "/run/user/1000/haven-0" 320 240 12632256)'
;
; our ids: 2 registry, 3 shm, 4 compositor, 5 wm_base, 6 surface,
; 7 xdg_surface, 8 toplevel, 99 the sync oar; pools/buffers pair up
; from 9 (9/10, 11/12, ..) -- a fresh pair per dress.
;
; the log book `got`: 0..2 the global names (shm compositor wm_base),
; 3 the sync echo, 4 the configure serial, 5 the release, 6/7 the
; configured w/h, 8 the last acked serial, 9/10 the dressed w/h,
; 11 the next pool id.
(:
   (skiff path w h rgb)
     (: c (connectu path)
        (? (! (lit? c)) 'no-socket
         (: k (cask 65536) sc (cask 65536)
            st (tablet 4) _ (pin st 0 0) _ (pin st 1 ())
            got (tablet 16)
            _ (map (\ i (pin got i 0)) '(0 1 2 3 4 5 6 7 8 9 10))
            _ (pin got 11 9)
            (on obj op off sz)
              (? (= obj 2)
                   (? (= op 0)
                      (: nm (wl-u32 k off) i (wl-rstr k (+ off 4))
                         (? (= i "wl_shm") (pin got 0 nm)
                            (= i "wl_compositor") (pin got 1 nm)
                            (= i "xdg_wm_base") (pin got 2 nm)
                            (= i "wl_seat") (pin got 13 nm)
                            (= i "zwp_text_input_manager_v3") (pin got 14 nm)
                            0))
                      0)
                 (= obj 99) (pin got 3 1)
                 (= obj 7) (? (= op 0) (pin got 4 (wl-u32 k off)) 0)
                 (= obj 8) (? (= op 0)                    ; toplevel.configure: a size
                              (: cw (wl-i32 k off) ch (wl-i32 k (+ off 4))
                                 (? (* cw ch) (: _ (pin got 6 cw) (pin got 7 ch)) 0))
                              (= op 1) (pin got 12 1)     ; toplevel.close: asked to part
                              0)
                 (= obj 201) (? (= op 0)                  ; text-input enter: enable + commit
                                (: _ (wl-ship c 201 1 () ()) (wl-ship c 201 7 () ()))
                                (= op 3)                  ; commit_string: say what we heard
                                (: t (wl-rstr k off)
                                   _ (puts "skiff: heard ") _ (puts t) (putc 10))
                                0)
                 (< 8 obj) (pin got 5 1)                  ; a buffer let go
                 0)
            (pump _) (: r (wl-pump c k sc st on) (? (< 0 r) (pump ()) r))
            (until i) (? (< 0 (peep got i 0)) (peep got i 0)
                         (: _ (await c) _ (pump ()) (until i)))
            ; dress: a fresh pool + buffer at (dw dh), brushed solid, committed
            (dress dw dh)
              (: stride (* dw 4) size (* stride dh)
                 fd (memfd size) m (mapfd fd size)
                 (? (? (< fd 0) 1 (< m 1)) ()
                  (: row (cask stride)
                     (fill i) (? (< i dw)
                                 (: _ (pin row (* i 4) (& 255 rgb))
                                    _ (pin row (+ (* i 4) 1) (& 255 (>> rgb 8)))
                                    _ (pin row (+ (* i 4) 2) (& 255 (>> rgb 16)))
                                    _ (pin row (+ (* i 4) 3) 0)
                                    (fill (+ i 1)))
                                 0)
                     _ (fill 0)
                     (paint y) (? (< y dh)
                                  (: _ (mapout m (* y stride) row 0 stride) (paint (+ y 1)))
                                  0)
                     _ (paint 0)
                     pool (peep got 11 9) buf (+ pool 1)
                     _ (pin got 11 (+ pool 2))
                     _ (wl-ship c 3 0 (L pool size) (L fd))       ; create_pool: the fd rides
                     _ (wl-ship c pool 0 (L buf 0 dw dh stride 1) ())   ; buffer, xrgb8888
                     _ (wl-ship c 6 1 (L buf 0 0) ())             ; attach
                     _ (wl-ship c 6 2 (L 0 0 dw dh) ())           ; damage
                     _ (wl-ship c 6 6 () ())                      ; commit
                     _ (unmap m size) _ (fdclose fd)
                     _ (pin got 9 dw) _ (pin got 10 dh)
                     1)))
            _ (wl-ship c 1 1 (L 2) ())                    ; get_registry
            _ (wl-ship c 1 0 (L 99) ())                   ; sync: the registry fence
            _ (until 3)
            (? (! (* (peep got 0 0) (* (peep got 1 0) (peep got 2 0))))
               (: _ (close c) 'no-globals)
             (: _ (wl-ship c 2 0 (link (peep got 0 0) (cat (wl-strw "wl_shm") (L 1 3))) ())
                _ (wl-ship c 2 0 (link (peep got 1 0) (cat (wl-strw "wl_compositor") (L 4 4))) ())
                _ (wl-ship c 2 0 (link (peep got 2 0) (cat (wl-strw "xdg_wm_base") (L 2 5))) ())
                _ (wl-ship c 4 0 (L 6) ())                ; create_surface
                _ (wl-ship c 5 2 (L 7 6) ())              ; get_xdg_surface
                _ (wl-ship c 7 1 (L 8) ())                ; get_toplevel
                _ (wl-ship c 6 6 () ())                   ; commit, bufferless
                srl (until 4)
                _ (pin got 8 srl)
                _ (wl-ship c 7 4 (L srl) ())              ; ack_configure
                dw (? (< 0 (peep got 6 0)) (peep got 6 0) w)
                dh (? (< 0 (peep got 7 0)) (peep got 7 0) h)
                (? (! (dress dw dh)) (: _ (close c) 'no-pool)
                 (: _ (until 5)                           ; the release lands
                    ; a text-input, when the harbor speaks it: seat 202, mgr 200,
                    ; ti 201 (high ids -- the pool pairs climb from 9). enter
                    ; (handled above) enables it; committed text prints
                    _ (? (? (< 0 (peep got 13 0)) (< 0 (peep got 14 0)) 0)
                         (: _ (wl-ship c 2 0 (link (peep got 13 0) (cat (wl-strw "wl_seat") (L 1 202))) ())
                            _ (wl-ship c 2 0 (link (peep got 14 0) (cat (wl-strw "zwp_text_input_manager_v3") (L 1 200))) ())
                            (wl-ship c 200 1 (L 201 202) ()))
                         0)
                    _ (puts "skiff: shipped")
                    ; hold the line: ack every fresh configure, re-dress on
                    ; a size change -- the compositor retiles, we follow; a
                    ; close asks us to part, and we go honestly (exit 0)
                    (hold _)
                      (: _ (await c) r (pump ())
                         (? (< 0 (peep got 12 0))
                            (: _ (puts "skiff: closed") (close c))
                            (< r 0)
                            (: s2 (peep got 4 0)
                               _ (? (= s2 (peep got 8 0)) 0
                                    (: _ (pin got 8 s2)
                                       _ (wl-ship c 7 4 (L s2) ())
                                       nw (? (< 0 (peep got 6 0)) (peep got 6 0) w)
                                       nh (? (< 0 (peep got 7 0)) (peep got 7 0) h)
                                       (? (? (= nw (peep got 9 0)) (= nh (peep got 10 0)) 0)
                                          0
                                          (dress nw nh))))
                               (hold ()))
                            (close c)))
                    (hold ())))))))))
