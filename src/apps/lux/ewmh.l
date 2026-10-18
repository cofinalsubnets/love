; src/apps/lux/ewmh.l -- EWMH + docks, so taskbars, pagers and fullscreen work:
;   * a support window advertising _net_supporting_wm_check + _net_wm_name;
;   * root properties a pager reads, re-published by ewmh-sync when the sheaf changes;
;   * struts: a dock's _net_wm_strut_partial shrinks the tiling rect; ewmh-toggle flips it.
; the strut arithmetic and encodings are pure; ewst is the one mutable cell. a body-less
; `:` -- leaks all.
(borrow 'xwire)
(:
   ; --- strut arithmetic. a strut is (left right top bottom ls le rs re ts te bs be):
   ;     reserved widths, then each edge's span, clamping a screen only where it meets ---
   (strut-parse vals) (? (#vals >= 12) (take 12 vals)                              ; _partial: the strut and its spans
                         (#vals >= 4) (take 4 vals + '(0 65535 0 65535 0 65535 0 65535))   ; _strut: the whole edge
                         ())
   (strut-shrink r st swp shp)
    (: (spans? a b lo hi) (lo <= b && a <= hi)                                  ; the span [lo hi] meets the screen's [a b]
       ys? (spans? (ry r) (ry r + rh r - 1)) xs? (spans? (rx r) (rx r + rw r - 1))
       x1 (ys? (st 4) (st 5) ? (mx2 (rx r) (st 0)) (rx r))
       y1 (xs? (st 8) (st 9) ? (mx2 (ry r) (st 2)) (ry r))
       x2 (ys? (st 6) (st 7) ? (mn2 (rx r + rw r) (swp - st 1)) (rx r + rw r))
       y2 (xs? (st 10) (st 11) ? (mn2 (ry r + rh r) (shp - st 3)) (ry r + rh r))
       (rct x1 y1 (mx2 0 (x2 - x1)) (mx2 0 (y2 - y1))))

   ; --- the EWMH state: one tablet ---
   ewst {'avoid 1 'struts () 'last ()}
   (ewmh-atom nm) (peep (peep ewst 'atoms (tablet 1)) nm 0)
   (ewmh-rect scrn swp shp)                                                      ; a screen's tiling rect: minus the struts reaching it (when avoiding)
    (? !(peep ewst 'avoid 0) scrn
       (foldl (r \ p \ strut-shrink r <>p swp shp) scrn (ewst 'struts)))
   (ewmh-toggle u) (pin ewst 'avoid !(ewst 'avoid))
   (ewmh-names tags) (foldl (a \ t \ a + show t + string 0) "" tags)            ; _net_desktop_names: NUL-terminated utf8 strings
   (ewmh-per tags vals) (foldl (a \ t \ a + vals) () tags)                       ; one row of vals per desktop
   (ewmh-track s win)                                                            ; read the window's strut; () if it has none
    (: vals (x-getprop-atoms s win (ewmh-atom "_NET_WM_STRUT_PARTIAL"))
       vals (two? vals ? vals (x-getprop-atoms s win (ewmh-atom "_NET_WM_STRUT")))
       st (strut-parse vals)
       (st ? (pin ewst 'struts ([win st] . filter (p \ <p != win) (ewst 'struts)), st)))
   (ewmh-untrack win) (pin ewst 'struts (filter (p \ <p != win) (ewst 'struts)))

   ; --- CreateWindow (opcode 1): the 1x1 InputOnly support window at (-1,-1) ---
   (x-mkwin s wid parent)
    (x-w8 s 1,       x-w8 s 0,      x-w16 s 8,     x-w32 s wid,
     x-w32 s parent, x-w16 s 65535, x-w16 s 65535, x-w16 s 1,
     x-w16 s 1,      x-w16 s 0,     x-w16 s 2,     x-w32 s 0, x-w32 s 0)                    ; border 0, class InputOnly, visual/values CopyFromParent

   ; --- ChangeProperty (opcode 18, mode Replace), format 32 and 8 ---
   (x-chprop32 s win prop type vals)
    (: n #vals (go (a . u)) (x-w32 s a, go u)
     (x-w8 s 18, x-w8 s 0, x-w16 s (6 + n), x-w32 s win, x-w32 s prop,
      x-w32 s type, x-w8 s 32, x-w8 s 0, x-w16 s 0, x-w32 s n,
      go vals))           ; an ordered loop: map's effects run tail-first
   (x-chprop8 s win prop type txt)
    (: n #txt (go i) (i < x-pad4 n ? (put s 0, go (i + 1)))
     (x-w8 s 18, x-w8 s 0, x-w16 s (6 + (n + x-pad4 n) / 4), x-w32 s win, x-w32 s prop,
      x-w32 s type, x-w8 s 8, x-w8 s 0, x-w16 s 0, x-w32 s n,
      x-wname s txt, go 0))

   ; --- init: intern the vocabulary, hoist the support window, write the root ---
   ewmh-atoms '("_NET_SUPPORTED" "_NET_SUPPORTING_WM_CHECK" "_NET_WM_NAME" "_NET_CLIENT_LIST"
                 "_NET_CLIENT_LIST_STACKING" "_NET_ACTIVE_WINDOW" "_NET_CURRENT_DESKTOP" "_NET_NUMBER_OF_DESKTOPS" "_NET_WM_DESKTOP"
                 "_NET_WM_STATE" "_NET_WM_STATE_FULLSCREEN" "_NET_WM_STATE_MODAL"
                 "_NET_WM_STATE_MAXIMIZED_VERT" "_NET_WM_STATE_MAXIMIZED_HORZ" "_NET_CLOSE_WINDOW"
                 "_NET_WM_STRUT" "_NET_WM_STRUT_PARTIAL" "_NET_WM_WINDOW_TYPE"
                 "_NET_DESKTOP_GEOMETRY" "_NET_DESKTOP_VIEWPORT" "_NET_WORKAREA" "_NET_DESKTOP_NAMES"
                 "_NET_WM_WINDOW_TYPE_DOCK" "_NET_WM_WINDOW_TYPE_DIALOG" "_NET_WM_WINDOW_TYPE_NOTIFICATION" "_NET_FRAME_EXTENTS"
                 "WM_CHANGE_STATE")                                              ; ICCCM iconify; not advertised
   (ewmh-init s root idbase tags)
    (: at (tablet 8)
       _ (each ewmh-atoms (nm \ pin at nm (x-intern s nm)))
       utf8 (x-intern s "UTF8_STRING")
       _ (pins ewst 'atoms at 'root root 'sup idbase)
       (a nm) (peep at nm 0)
       (x-mkwin s idbase root,
        x-chprop32 s root (a "_NET_SUPPORTED") 4                                           ; type atom(4); only the _net_ vocabulary
                   (map (nm \ peep at nm 0) (filter (nm \ snip nm 0 5 = "_NET_") ewmh-atoms)),
        x-chprop32 s root (a "_NET_SUPPORTING_WM_CHECK") 33 [idbase],                     ; type window(33)
        x-chprop32 s idbase (a "_NET_SUPPORTING_WM_CHECK") 33 [idbase],
        x-chprop8 s idbase (a "_NET_WM_NAME") utf8 ("lux / love " + love-version),
        x-chprop32 s root (a "_NET_NUMBER_OF_DESKTOPS") 6 [#tags],                        ; type cardinal(6)
        x-chprop32 s root (a "_NET_DESKTOP_VIEWPORT") 6 (ewmh-per tags '(0 0)),           ; no large desktops: every viewport (0 0)
        x-chprop8 s root (a "_NET_DESKTOP_NAMES") utf8 (ewmh-names tags),
        x-flush s))

   ; --- sync: publish the sheaf when it changed; scrn is the root rect ---
   (ewmh-sync s sh scrn)
    (: wins (wswins sh) cur (wscur sh - 1)
       foc (wsfoc sh ? (wsfoc sh) 0)                                             ; wsfoc names a focused float too
       wa (ewmh-rect scrn (scrn 2) (scrn 3))
       key [cur foc wins scrn wa]
       (key = ewst 'last ? 0
          (: _ (pin ewst 'last key) root (peep ewst 'root 0) tags (map cap (wsboard sh))
             (x-chprop32 s root (ewmh-atom "_NET_DESKTOP_GEOMETRY") 6 [(scrn 2) (scrn 3)],
              x-chprop32 s root (ewmh-atom "_NET_WORKAREA") 6 (ewmh-per tags wa),      ; the root minus every strut, per desktop
              x-chprop32 s root (ewmh-atom "_NET_CLIENT_LIST") 33 wins,
              x-chprop32 s root (ewmh-atom "_NET_CLIENT_LIST_STACKING") 33 wins,   ; libwnck's taskbar reads this; wswins is bottom to top
              x-chprop32 s root (ewmh-atom "_NET_CURRENT_DESKTOP") 6 [cur],
              x-chprop32 s root (ewmh-atom "_NET_ACTIVE_WINDOW") 33 [foc],
              map (p \ (<p - 1 @ t                                               ; every window wears its workspace
                          (map (w \ x-chprop32 s w (ewmh-atom "_NET_WM_DESKTOP") 6 [t]) (zrow <>p)))) (wsboard sh),
              x-flush s))))

   ; --- ClientMessage (event 33) field reads, off the raw bytes ---
   (ewmh-cm-win pkt) (u32 pkt 4)  (ewmh-cm-type pkt) (u32 pkt 8)
   (ewmh-cm-d0 pkt) (u32 pkt 12)  (ewmh-cm-d1 pkt) (u32 pkt 16)  (ewmh-cm-d2 pkt) (u32 pkt 20))
