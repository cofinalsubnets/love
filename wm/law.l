; wm/law.l -- xmonad's QuickCheck properties for wm/core.l, in exact arithmetic,
; plus a seeded fuzz. Reads the LEAKED globals from wm/core.l (concatenate them:
; `cat test/00-init.l wm/core.l wm/law.l | ai`, the `make test_wm` gate). Split
; into small independent top-level `:` forms -- each self-contained, nothing new
; leaks, and no single form grows big enough to stress the whole-form compiler.

; --- the zipper laws ---
(: z3 (zmk 2 '(1) '(3))                                                          ; row (1 2 3), 2 focused
   (assert
      (= (zrow (zfrom '(1 2 3))) '(1 2 3)) (! (zfrom ())) (! (zrow ()))
      (= (zrow z3) '(1 2 3)) (= (zfoc z3) 2)
      (= (zfocdn (zfocup z3)) z3) (= (zfocup (zfocdn z3)) z3)                    ; motions are inverses
      (= (zfoc (zfocup z3)) 1) (= (zfoc (zfocdn z3)) 3)
      (= (zfoc (zfocup (zfocup z3))) 3)                                          ; wrap past the top -> the bottom
      (= ((3 zfocup) z3) z3) (= ((3 zfocdn) z3) z3)                              ; the church numeral IS the cycle law
      (= (zfocup (zmk 7 () ())) (zmk 7 () ()))                                   ; a singleton is a fixed point
      (= (zswapdn (zswapup z3)) z3) (= (zswapup (zswapdn z3)) z3)                ; swaps are inverses
      (= (zfoc (zswapup z3)) 2) (= (zrow (zswapup z3)) '(2 1 3))
      (= (zrow (zswapup (zfocup z3))) '(2 3 1))                                  ; swapping the top rotates it down
      (= (zrow (zmaster z3)) '(2 1 3)) (= (zmaster (zmaster z3)) (zmaster z3))   ; master fronts the focus, idempotent
      (= (zrow (zins 9 z3)) '(1 9 2 3)) (= (zfoc (zins 9 z3)) 9)
      (= (zdel 2 z3) (zmk 3 '(1) ())) (= (zrow (zdel 1 z3)) '(2 3))
      (= (zdel 9 z3) z3) (! (zdel 1 (zmk 1 () ())))))

; --- the sheaf laws ---
(: (sameset? a b) (&& (= (tally a) (tally b)) (all (\ x (any (\ y (= x y)) b)) a))   ; equal as sets
   s0 (sheaf '(1 2 3)) s1 (admit s0 10) s2 (admit (admit s1 20) 30)             ; ws1 row (30 20 10)
   s4 (shiftto s2 2)
   (assert
      (= (wscur s0) 1) (! (wsrow s0)) (! (wsfoc s0)) (wssane? s0)
      (= (wsfoc s1) 10) (= (wsrow s1) '(10)) (wsknownw? s1 10) (wssane? s1)
      (= (admit s1 10) s1)                                                       ; managing a managed window is a no-op
      (= (wsrow s2) '(30 20 10)) (= (wsfoc s2) 30) (wssane? s2)
      (= (wscur (wsview s2 2)) 2) (! (wsfoc (wsview s2 2)))                      ; view: only the tag turns
      (= (wsview s2 9) s2) (= (wsview (wsview s2 2) 1) s2)
      (sameset? (wswins (wsview s2 2)) (wswins s2))                             ; view moves no windows
      (= (wscur s4) 1) (= (wstagof s4 30) 2) (= (wsfoc s4) 20) (= (wsrow s4) '(20 10)) (wssane? s4)
      (= (shiftto s2 1) s2) (= (shiftto s2 9) s2)                               ; to self / to nowhere: no-ops
      (! (wsknownw? (evict s2 20) 20)) (= (wsrow (evict s2 20)) '(30 10))
      (= (wsfoc (evict s2 30)) 20) (wssane? (evict s2 30))
      (= (wstagof s2 10) 1) (! (wstagof s2 99))))

; --- the floating half (W.float / W.sink) ---
(: s2 (admit (admit (admit (sheaf '(1 2 3)) 10) 20) 30) r99 '(20 20 200 100)
   (sameset? a b) (&& (= (tally a) (tally b)) (all (\ x (any (\ y (= x y)) b)) a))
   f2 (wsdofloat s2 20 r99)
   (assert
      (! (wsfloating? s2 20)) (wsfloating? f2 20) (= (wsrect f2 20) r99)         ; float lifts a window
      (wsknownw? f2 20) (= (wsrect f2 30) ())                                    ; still managed; a tiled window has no rect
      (! (any (\ x (= x 20)) (wstiled f2)))                                      ; float removed 20 from the tiled stack
      (sameset? (wswins f2) (wswins s2))                                         ; float moves it between sets, not out
      (! (wsfloating? (wssink f2 20) 20)) (sameset? (wswins (wssink f2 20)) (wswins s2))))   ; sink is float's inverse

; --- the seeded fuzz: the whole op vocabulary, 200 steps, invariant per step ---
(: r99 '(20 20 200 100)
   (fzop k w s)
    (? (= k 0) (admit s w)     (= k 1) (evict s w)
       (= k 2) (wsmap s zfocup) (= k 3) (wsmap s zfocdn)
       (= k 4) (wsmap s zswapup) (= k 5) (wsmap s zswapdn)
       (= k 6) (wsmap s zmaster) (= k 7) (wsview s (+ 1 (% w 3)))
       (= k 8) (shiftto s (+ 1 (% w 3)))
       (: fw (wsfoc s) (? fw (? (wsfloating? s fw) (wssink s fw) (wsdofloat s fw r99)) s)))   ; toggle-float the focus
   (fz i st s)
    (? (< i 1) s
       (: r1 (random st 10) r2 (random (cup r1) 40)
          s2 (fzop (cap r1) (+ 1 (cap r2)) s)
          (? (wssane? s2) (fz (- i 1) (cup r2) s2) (L 'broke (cap r1) (+ 1 (cap r2))))))
   sF (fz 200 (seed 7) (sheaf '(1 2 3)))
   (assert (wssane? sF) (all (\ w (|| (wsfloating? sF w) (wsknown? sF (wstagof sF w)))) (wswins sF))))

; --- the layout engine (wm/layout.l): geometry is a partition ---
(: (area p) (* (nthl p 3) (nthl p 4))                                            ; a placement's w*h
   (sumarea ps) (foldl (\ a p (+ a (area p))) 0 ps)
   r (rct 0 0 800 600) full-area 480000
   z1 (zfrom '(10)) z3 (zfrom '(10 20 30))                                       ; z3 focuses the master (10)
   L1 (resizable-tall 1 0.02 0.5)
   t1 (cap (lay-tile L1 r z1)) t3 (cap (lay-tile L1 r z3))
   (assert
      ; ResizableTall partitions the rect exactly, master-left / slaves-right
      (= (tally t3) 3) (= (sumarea t3) full-area)
      (= (cap t3) '(10 0 0 400 600))                                             ; master owns the left half
      (= (caup t3) '(20 400 0 400 300)) (= (nthl t3 2) '(30 400 300 400 300))    ; two slaves stack in the right half
      (= (tally t1) 1) (= (cap t1) '(10 0 0 800 600))                            ; a lone window fills the screen
      ; Shrink / Expand nudge the master ratio by delta (master width, was 400)
      (: mw- (nthl (cap (cap (lay-tile (lay-msg L1 'shrink z3) r z3))) 3)
         mw+ (nthl (cap (cap (lay-tile (lay-msg L1 'expand z3) r z3))) 3)
         (&& (< mw- 400) (> mw- 380) (> mw+ 400) (< mw+ 420)))
      (= (nthl (lay-msg (lay-msg L1 'expand z3) 'shrink z3) 2) 0.5)             ; expand then shrink is a round trip
      ; IncMasterN grows the master column (2 masters left, 1 slave right)
      (: L2 (lay-msg L1 'inc-master z3) p (cap (lay-tile L2 r z3))
         (&& (= (nthl (cap p) 1) 0) (= (nthl (caup p) 1) 0) (= (nthl (nthl p 2) 1) 400)))   ; two masters at x=0, slave at x=400
      (= (nthl (lay-msg (lay-msg L1 'inc-master z3) 'dec-master z3) 1) 1)        ; dec undoes inc; floored at 1
      (= (nthl (lay-msg L1 'dec-master z3) 1) 1)
      ; Full places only the focus, whole rect
      (: f (cap (lay-tile full r z3)) (&& (= (tally f) 1) (= (cap f) '(10 0 0 800 600))))
      ; MirrorShrink shrinks the FOCUSED slave (focus 20, the first slave)
      (: zs (zfocdn z3) M (lay-msg L1 'mirror-shrink zs) h20 (nthl (caup (cap (lay-tile M r zs))) 4)
         (&& (< h20 300) (> h20 250)))
      ; ||| holds the layouts; NextLayout cycles the index (tall -> full -> tall)
      (: C (choice (L L1 full))
         (&& (= (tally (cap (ch-tile C r z3))) 3)                               ; index 0 = ResizableTall
             (= (tally (cap (ch-tile (lay-msg C 'next-layout z3) r z3))) 1)     ; index 1 = Full
             (= (nthl (lay-msg (lay-msg C 'next-layout z3) 'next-layout z3) 1) 0)))   ; wraps back to 0
      ; a message ||| doesn't know (shrink) delegates to the active sublayout
      (= (nthl (ch-cur (lay-msg (choice (L L1 full)) 'shrink z3)) 2) 0.48)))

; --- the layout modifiers (wm/layout.l rung 4): each wraps a layout ---
(: (area p) (* (nthl p 3) (nthl p 4))
   (sumarea ps) (foldl (\ a p (+ a (area p))) 0 ps)
   r (rct 0 0 800 600) z3 (zfrom '(10 20 30)) z1 (zfrom '(10))
   L1 (resizable-tall 1 0.02 0.5)
   base (choice (L L1 (dwindle 1.618)))
   stk (minimize (smart-borders (toggle-full (mirror base))))                    ; the config's t (l1 ||| l2) shape
   (assert
      ; MIRROR transposes: master moves to the TOP, the partition is preserved
      (: m (lay-msg (mirror L1) 'mirror z3) p (cap (lay-tile m r z3))            ; toggle MIRROR on
         (&& (= (cap p) '(10 0 0 800 300)) (= (sumarea p) 480000)))               ; master owns the top strip
      (= (lay-tile (mirror L1) r z3) (L (cap (lay-tile L1 r z3)) (mirror L1)))    ; MIRROR off is a pass-through
      ; Dwindle is a golden spiral: the focus takes phi/(1+phi) of the width, still a partition
      (: p (cap (lay-tile (dwindle 1.618) r z3))
         (&& (= (nthl (cap p) 3) (int (* (/ 1.618 2.618) 800))) (= (sumarea p) 480000) (= (tally p) 3)))
      ; toggleLayouts Full: off = inner, on = the focus fullscreen
      (= (tally (cap (lay-tile (toggle-full L1) r z3))) 3)
      (= (cap (cap (lay-tile (lay-msg (toggle-full L1) 'toggle-layout z3) r z3))) '(10 0 0 800 600))
      ; smartBorders: a lone window (or a fullscreen one) gets a border-0 hint (a 6th field)
      (: p (cap (lay-tile (smart-borders L1) r z1)) (&& (= (tally (cap p)) 6) (= (nthl (cap p) 5) 0)))
      (: p (cap (lay-tile (smart-borders L1) r z3)) (all (\ q (= (tally q) 5)) p))   ; multi-window: no border hint
      ; minimize filters a window out of the row; the rest re-tile; restore brings it back
      (: p (cap (lay-tile (lay-msg (minimize L1) (L 'minimize-window 20) z3) r z3))
         (&& (= (tally p) 2) (! (afind (\ q (= (nthl q 0) 20)) p))))
      (: mm (lay-msg (lay-msg (minimize L1) (L 'minimize-window 20) z3) 'restore z3)
         (= (tally (cap (lay-tile mm r z3))) 3))
      ; windowNavigation geometry: nearest window in a direction
      (: pls (cap (lay-tile L1 r z3))
         (&& (= (nav-target pls 10 'right) 20) (! (nav-target pls 10 'left))     ; master: right -> a slave, nothing left
             (= (nav-target pls 20 'left) 10) (= (nav-target pls 20 'down) 30))) ; slave: left -> master, down -> the other slave
      ; the WHOLE config stack composes: message pass-through reaches the base, partition holds
      (= (sumarea (cap (lay-tile stk r z3))) 480000)
      (= (tally (cap (lay-tile (lay-msg stk 'next-layout z3) r z3))) 3)          ; next-layout reaches the ||| at the bottom
      (: q (cap (lay-tile (lay-msg stk 'toggle-layout z3) r z3)) (&& (= (tally q) 1) (= (nthl (cap q) 5) 0)))))   ; toggle-full through the stack -> fullscreen, borderless

; --- the manageHook DSL (wm/manage.l rung 5): combinators + float actions ---
(: s0 (admit (admit (sheaf '(1 2 3)) 10) 20)                                     ; ws1 tiled (20 10); we manage 20
   c (mg-ctx 0 20 (rct 0 0 800 600) (rct 100 100 300 200))                      ; socket 0 (unused: pure actions/mocks), win 20, screen, geom
   yes (\ c 1) no (\ c 0)                                                        ; mock predicates
   tag (\ nm (\ c sh (link nm sh)))                                             ; mock action: cons a tag onto the sheaf (marks it ran)
   (assert
      ; float actions move the (tiled) window into the floating half at the right rect
      (: f (do-full-float c s0) (&& (wsfloating? f 20) (= (wsrect f 20) '(0 0 800 600)) (! (any (\ x (= x 20)) (wstiled f)))))
      (: f (do-float c s0) (= (wsrect f 20) '(100 100 300 200)))                ; do-float keeps the window's own geometry
      (: f (do-center-float c s0) (= (wsrect f 20) '(250 200 300 200)))         ; centered: (800-300)/2=250, (600-200)/2=200
      (= (do-ignore c s0) (evict s0 20))                                        ; ignore un-manages entirely
      ; <||> is predicate OR
      ((<||> yes no) c) (! ((<||> no no) c)) ((<||> no yes) c)
      ; -?> fires the action iff the predicate matches (a 1-list = matched, () = not)
      (= ((-?> yes (tag 'a)) c s0) (L (link 'a s0)))
      (! ((-?> no (tag 'a)) c s0))
      ; compose-one takes the FIRST matching rule; none -> the sheaf unchanged
      (= ((compose-one (L (-?> no (tag 'a)) (-?> yes (tag 'b)) (-?> yes (tag 'c)))) c s0) (link 'b s0))
      (= ((compose-one (L (-?> no (tag 'a)) (-?> no (tag 'b)))) c s0) s0)
      ; compose-all threads every hook (a plain hook, so wrap or use identity)
      (= ((compose-all (L (\ c sh (link 'x sh)) (\ c sh (link 'y sh)))) c s0) (link 'y (link 'x s0)))
      ; manage-default is the assembled config hook -- a runnable closure (X-driven; not called here)
      (lit? manage-default)))

(say err "wm/law: StackSet zipper + sheaf + floating + layout + modifier + manage laws ok
")
