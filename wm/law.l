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

(say err "wm/law: StackSet zipper + sheaf + floating + layout laws ok
")
