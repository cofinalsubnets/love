; test/law/lux.l -- xmonad's QuickCheck properties for lux, in exact arithmetic, plus a
; seeded fuzz. small self-contained top-level `:` forms, so nothing leaks

; --- the zipper laws ---
(borrow 'xwire)
(borrow 'salt)    ; config.l splices salt too, and a splice is not inherited
(borrow 'lux)     ; core.l through config.l, one module
(zmk 2 '(1) '(3) @ z3                                                            ; row (1 2 3), 2 focused
 (test
    (zrow (zfrom '(1 2 3)) = '(1 2 3)) !(zfrom ()) !(zrow ())
    (zrow z3 = '(1 2 3)) (zfoc z3 = 2)
    (zfocdn (zfocup z3) = z3) (zfocup (zfocdn z3) = z3)
    (zfoc (zfocup z3) = 1) (zfoc (zfocdn z3) = 3)
    (zfoc (zfocup (zfocup z3)) = 3)                                              ; wrap past the top
    (3 zfocup z3 = z3) (3 zfocdn z3 = z3)                                        ; the church numeral is the cycle law
    (zfocup (zmk 7 () ()) = zmk 7 () ())
    (zswapdn (zswapup z3) = z3) (zswapup (zswapdn z3) = z3)
    (zfoc (zswapup z3) = 2) (zrow (zswapup z3) = '(2 1 3))
    (zrow (zswapup (zfocup z3)) = '(2 3 1))                                      ; swapping the top rotates it down
    (zrow (zmaster z3) = '(2 1 3)) (zmaster (zmaster z3) = zmaster z3)           ; idempotent
    (zrow (zins 9 z3) = '(1 9 2 3)) (zfoc (zins 9 z3) = 9)
    (zdel 2 z3 = zmk 3 '(1) ()) (zrow (zdel 1 z3) = '(2 3))
    (zdel 9 z3 = z3) !(zdel 1 (zmk 1 () ()))))

; --- the sheaf laws ---
(: (sameset? a b) (#a = #b && all (x \ any (y \ x = y) b) a)
   s0 (sheaf '(1 2 3)) s1 (admit s0 10) s2 (admit (admit s1 20) 30)             ; ws1 row (30 20 10)
   s4 (shiftto s2 2)
   (test
      (wscur s0 = 1) !(wsrow s0) !(wsfoc s0) (wssane? s0)
      (wsfoc s1 = 10) (wsrow s1 = '(10)) (wsknownw? s1 10) (wssane? s1)
      (admit s1 10 = s1)                                                         ; a no-op
      (wsrow s2 = '(30 20 10)) (wsfoc s2 = 30) (wssane? s2)
      (wscur (wsview s2 2) = 2) !(wsfoc (wsview s2 2))                           ; only the tag turns
      (wsview s2 9 = s2) (wsview (wsview s2 2) 1 = s2)
      (sameset? (wswins (wsview s2 2)) (wswins s2))
      (wscur s4 = 1) (wstagof s4 30 = 2) (wsfoc s4 = 20) (wsrow s4 = '(20 10)) (wssane? s4)
      (shiftto s2 1 = s2) (shiftto s2 9 = s2)
      (shiftwin s2 10 3 @ s5                                                    ; 10 leaves, focus stays 30
       (wstagof s5 10 = 3 && wsrow s5 = '(30 20) && wsfoc s5 = 30 && wssane? s5))
      (shiftwin s2 10 1 = s2) (shiftwin s2 99 2 = s2)
      !(wsknownw? (evict s2 20) 20) (wsrow (evict s2 20) = '(30 10))
      (wsfoc (evict s2 30) = 20) (wssane? (evict s2 30))
      (wstagof s2 10 = 1) !(wstagof s2 99)
      (wsring s2 = '(30 20 10))))                                               ; no floats: the ring is the tiled row

; --- the floating half (W.float / W.sink): geometry alone, so float and sink never move the ring ---
(: s2 (admit (admit (admit (sheaf '(1 2 3)) 10) 20) 30) r99 '(20 20 200 100)
   (sameset? a b) (#a = #b && all (x \ any (= x) b) a)
   f2 (wsdofloat s2 20 r99)
   g (wsmap f2 (zfocto 20))
   h (wsswapup (wsmap f2 (zfocto 10)))
   (test
      !(wsfloating? s2 20) (wsfloating? f2 20) (wsrect f2 20 = r99)
      (wsknownw? f2 20) (wsrect f2 30 = ())                                      ; a tiled window has no rect
      !(any (= 20) (wstiled f2))
      (sameset? (wswins f2) (wswins s2))
      (wssink f2 20 = s2)                                                        ; float's exact inverse
      ; --- geometry only: the ring slot belongs to the window, float or not ---
      (wsring f2 = wsring s2) (wsring f2 = '(30 20 10))
      (wsrow f2 = '(30 10)) (wsfoc f2 = 30)                                      ; the float-free subsequence
      (wsvisfl f2 = [[20 r99]])
      ; --- the home tag is structural: whichever zipper holds it ---
      (1 = wstagof f2 20)                                                        ; floated while viewing tag 1
      (1 = wstagof (wsview f2 2) 20)
      (two? (wsvisfl f2)) !(two? (wsvisfl (wsview f2 2)))                        ; visible at home, hidden abroad
      (1 = wstagof (wsdofloat (wsview f2 2) 20 '(0 0 9 9)) 20)                   ; a drag keeps the home
      (2 = wstagof (shiftwin f2 20 2) 20)
      (r99 = wsrect (shiftwin f2 20 2) 20)
      (wssane? (shiftwin f2 20 2)) (shiftwin f2 20 1 = f2)
      !(any (= 20) (wsring (wsview f2 2)))
      ; --- one focus: wsfoc names a float, and a view round trip returns it ---
      (wsfoc g = 20) (wsfoc (wsview (wsview g 2) 1) = 20)
      (wsmaster g = g) (wsswapup g = g)                                          ; the order ops are tiles-only
      (wsring h = '(10 20 30)) (wsrow h = '(10 30)) (wsflhere h = '(20))))       ; the float keeps its own slot

; --- float stacking, bottom to top: the ring reversed, the focus and its owners last, a transient over its owner ---
(: fl '(1 2 3 4) (none w) () (by4 w) (w = 2 ? 4) (cyc w) (w @ 1 2 2 1 ())
   (test
      (wsstack fl () none = '(4 3 2 1)) (wsstack fl 3 none = '(4 2 1 3))
      (wsstack fl () by4 = '(4 2 3 1))                                           ; 2 serves 4: just above it
      (wsstack fl 4 by4 = '(3 1 4 2)) (wsstack fl 2 by4 = '(3 1 4 2))            ; focus on either lifts the pair, the dialog on top
      (wsstack '(30 20 40 10) 10 (w \ w = 40 ? 10) = '(20 30 10 40))           ; a dialog opened from a focused owner low in the ring
      (wsstack fl () (w \ w = 1 ? 99) = '(4 3 2 1))                             ; an owner off the list is no owner
      (wsstack fl () (w \ w) = '(4 3 2 1))                                      ; nor is the window itself
      (wsstack '(1 2) () cyc = '(2 1))                                           ; an owner cycle keeps every window
      (wsstack () 5 none = ())))

; --- the screens (xmonad's current/visible/hidden): vis is ((tag rect)..) in screen order ---
(: r1 '(0 0 800 600) r2 '(800 0 800 600) r3 '(1600 0 800 600) r4 '(2400 0 800 600)
   s0 (sheaf '(1 2 3)) s2 (wsrescreen s0 [r1 r2])                               ; tags 1 and 2 on view, 3 hidden
   (test
      (wsvistags s0 = '(1)) !(wsrectof s0 1) (wshidden s0 = '(2 3)) (wssane? s0)   ; born single-screen, the rect unknown
      (wsvistags s2 = '(1 2)) (wsrectof s2 2 = r2) (wscur s2 = 1) (wshidden s2 = '(3)) (wssane? s2)
      (wsvisible? s2 2) !(wsvisible? s2 3) !(wsrectof s2 3)
      (wscur (wsview s2 2) = 2) (wsvistags (wsview s2 2) = '(1 2))              ; no screen changes
      (wscur (wsview s2 3) = 3) (wsvistags (wsview s2 3) = '(3 2))              ; a hidden tag takes the current screen
      (wsrectof (wsview s2 3) 3 = r1) (wsview (wsview s2 3) 1 = s2)
      (wsview s2 1 = s2) (wsview s2 9 = s2)
      (wscur (wsgreedy s2 2) = 2) (wsvistags (wsgreedy s2 2) = '(2 1))           ; greedy: the tags trade screens
      (wsrectof (wsgreedy s2 2) 2 = r1) (wsrectof (wsgreedy s2 2) 1 = r2)
      (wsgreedy s2 3 = wsview s2 3) (wsgreedy s2 1 = s2)                         ; on a hidden tag greedy is view
      (wsgreedy (wsgreedy s2 2) 1 = s2)
      (wssane? (wsview s2 3)) (wssane? (wsgreedy s2 2))
      (wsvistags (wsrescreen s2 [r1]) = '(1)) (wssane? (wsrescreen s2 [r1]))     ; a screen gone: its tag hides
      (wscur (wsrescreen (wsview s2 2) [r1]) = 1)                                ; the first left is current
      (wsvistags (wsrescreen (wsview s2 3) [r1 r2 r3]) = '(3 2 1))              ; the first hidden tag fills it
      (wsvistags (wsrescreen s0 [r1 r2 r3 r4]) = '(1 2 3))                       ; the spare stays dark
      (wsrescreen s2 () = s2)                                                     ; refused
      (wsrescreen s2 [r2 r1] = s2)                                               ; screens go by position: a primary flip moves nothing
      (wsvis (wsrescreen s0 [r2 '(0 700 800 600) r1]) = [[1 r1] [2 '(0 700 800 600)] [3 r2]])   ; x first, then y
      (wsvistags (wsrescreen s0 [r1 r1 r2]) = '(1 2))                             ; a clone is one screen
      (wsvis (wsrescreen s0 [r1 '(100 100 200 200)]) = [[1 r1]])
      (wsvis (wsrescreen s0 ['(100 100 200 200) r1]) = [[1 r1]])                  ; the container stays
      (wsclean [r1 '(0 0 800 600) r2] = [r1 r2]) (wsclean () = ())))

; --- per screen: what each screen paints, and focus across screens ---
(: r1 '(0 0 800 600) r2 '(800 0 800 600) r99 '(1 1 9 9)
   s2 (wsrescreen (admit (admit (admit (sheaf '(1 2 3)) 10) 20) 30) [r1 r2])   ; tag 1 (30 20 10) on r1, tag 2 empty on r2, 3 hidden
   s3 (shiftwin (wsdofloat s2 20 r99) 30 2)
   s4 (shiftwin s3 10 3)
   (test
      (wsringof s3 1 = '(20 10)) (wsringof s3 2 = '(30)) !(wsringof s3 3)
      (zrow (wstilezof s3 1) = '(10)) (wsvisflof s3 1 = [[20 r99]]) !(wsvisflof s3 2)
      (wsonscreen s3 = '(20 10 30)) (wsonscreen s4 = '(20 30))
      (wsscreenof s3 30 = r2) (wsscreenof s3 10 = r1) !(wsscreenof s4 10) !(wsscreenof s3 99)
      (wsscreenat s3 10 10 = 1) (wsscreenat s3 800 599 = 2) (wsscreenat s3 799 0 = 1)   ; edges go to the right screen
      !(wsscreenat s3 1600 10) !(wsscreenat s3 10 600) !(wsscreenat (sheaf '(1 2)) 10 10)   ; off every screen, or no rect yet
      (wscur (wsfocw s3 30) = 2) (wsfoc (wsfocw s3 30) = 30) (wssane? (wsfocw s3 30))   ; the screen follows
      (wscur (wsfocw s3 10) = 1) (wsfoc (wsfocw s3 10) = 10)
      (wsfocw s4 10 = s4) (wsfocw s3 99 = s3)
      (wsvistags (wsfocw s3 30) = '(1 2))))

; --- a float centred on another screen takes that screen's tag, focus and currency;
; hidden, or on its own screen, nothing moves ---
(: r1 '(0 0 800 600) r2 '(800 0 800 600)
   s2 (wsrescreen (admit (admit (sheaf '(1 2 3)) 10) 20) [r1 r2])
   f (wsdofloat s2 10 '(900 100 200 100))                                       ; centre 1000: the right screen
   g (wsdofloat s2 10 '(600 100 200 100))                                       ; centre 700: its own
   (test
      (wstagof f 10 = 2) (wscur f = 2) (wsfoc f = 10) (wsfloating? f 10) (wsrect f 10 = '(900 100 200 100)) (wssane? f)
      (wsring f = '(10)) (wsringof f 1 = '(20))
      (wstagof g 10 = 1) (wscur g = 1) (wsfloating? g 10)
      (wsdofloat f 10 '(900 100 200 100) = f)
      (wstagof (wsdofloat f 10 '(100 100 200 100)) 10 = 1)
      (wstagof (wsdofloat (wsview s2 3) 10 '(900 100 200 100)) 10 = 1)          ; tag 3 took its screen
      (wstagof (wsdofloat s2 10 '(1700 100 200 100)) 10 = 1)
      (wssink f 10 = wsfocw (shiftwin s2 10 2) 10)))                             ; sinking keeps the new home

; --- the seeded fuzz: the whole op vocabulary, 200 steps, invariant per step ---
(: r99 '(20 20 200 100) rA '(0 0 1 1) rB '(1 0 1 1)
   (fzop k w s) (k @
    0 (admit s w)      1 (evict s w)
    2 (wsmap s zfocup) 3 (wsmap s zfocdn)
    4 (wsswapup s) 5 (wsswapdn s)
    6 (wsmaster s) 7 (wsview s (1 + (w % 3)))
    8 (shiftto s (1 + (w % 3)))
    9 (wsgreedy s (1 + (w % 3)))
    10 (wsrescreen s (take (1 + (w % 2)) [rA rB]))
    (wsfoc s @ fw (fw ? (wsfloating? s fw ? (wssink s fw) (wsdofloat s fw r99)) s)))
   (fz i st s)
    (i < 1 ? s
       (: r1 (random st 12) r2 (random >r1 40)
          s2 (fzop <r1 (1 + <r2) s)
          (wssane? s2 ? (fz (i - 1) >r2 s2) ['broke <r1 (1 + <r2)])))
   sF (fz 200 (wheel 7) (sheaf '(1 2 3)))
   (test (wssane? sF) (all (w \ wsknown? sF (wstagof sF w)) (wswins sF))              ; every window has a real tag
         (wsvisible? sF (wscur sF)) (all (t \ wsknown? sF t) (wsvistags sF))
         (all (w \ wstagof sF w = wscur sF) (wsring sF))
         (wsrow sF = filter (w \ !(wsfloating? sF w)) (wsring sF))))

; --- the layout engine (layout.l): geometry is a partition ---
(: (area p) (p 3 * p 4)
   (sumarea ps) (foldl (a \ p \ a + area p) 0 ps)
   r (rct 0 0 800 600) full-area 480000
   z1 (zfrom '(10)) z3 (zfrom '(10 20 30))
   L1 (resizable-tall 1 0.02 0.5)
   t1 <(lay-tile L1 r z1) t3 <(lay-tile L1 r z3)
   (test
      ; ResizableTall partitions the rect exactly, master-left / slaves-right
      (#t3 = 3) (sumarea t3 = full-area)
      (<t3 = '(10 0 0 400 600))
      (<>t3 = '(20 400 0 400 300)) (t3 2 = '(30 400 300 400 300))
      (#t1 = 1) (<t1 = '(10 0 0 800 600))
      ; Shrink / Expand nudge the master ratio by delta
      (: mw- (<<(lay-tile (lay-msg L1 'shrink z3) r z3) 3)
         mw+ (<<(lay-tile (lay-msg L1 'expand z3) r z3) 3)
         (mw- < 400 && mw- > 380 && mw+ > 400 && mw+ < 420))
      (lay-msg (lay-msg L1 'expand z3) 'shrink z3 2 = 0.5)
      ; IncMasterN grows the master column
      (: L2 (lay-msg L1 'inc-master z3) p <(lay-tile L2 r z3)
         ((<p 1 = 0) && (<>p 1 = 0) && (p 2 1 = 400)))
      (lay-msg (lay-msg L1 'inc-master z3) 'dec-master z3 1 = 1)            ; floored at 1
      (lay-msg L1 'dec-master z3 1 = 1)
      ; Full places only the focus, whole rect
      (<(lay-tile full r z3) @ f (#f = 1 && <f = '(10 0 0 800 600)))
      ; MirrorShrink shrinks the focused slave (20)
      (: zs (zfocdn z3) M (lay-msg L1 'mirror-shrink zs) h20 (<><(lay-tile M r zs) 4)
         (250 < h20 < 300))
      ; ||| holds the layouts; NextLayout cycles the index
      (choice [L1 full] @ C
       (#<(ch-tile C r z3) = 3
        && #<(ch-tile (lay-msg C 'next-layout z3) r z3) = 1
        && lay-msg (lay-msg C 'next-layout z3) 'next-layout z3 1 = 0))
      ; a message ||| doesn't know delegates to the active sublayout
      (ch-cur (lay-msg (choice [L1 full]) 'shrink z3) 2 = 0.48)))

; --- the book: one layout per tag, () = every tag on the default ---
(: L1 (resizable-tall 1 0.02 0.5) b1 (lays-put () 2 full)
   (test
      (lays-of () 1 L1 = L1)
      (lays-of b1 2 L1 = full) (lays-of b1 1 L1 = L1)
      (lays-of (lays-put b1 2 L1) 2 full = L1) (#(lays-put b1 2 L1) = 1)
      (#(lays-put b1 1 L1) = 2)))

; --- the tiling ledger: rt-tile places every window of the row once, none invented, in
; row order, whatever the master count ---
(: (wincol ps) (two? ps ? (<<ps . wincol >ps) ())
   r (rct 0 0 800 600) ws '(10 20 30 40 50) z (zfrom ws)
   (test
      (wincol <(lay-tile (resizable-tall 1 0.02 0.5) r z) = ws)
      (wincol <(lay-tile (resizable-tall 3 0.02 0.5) r z) = ws)
      (wincol <(lay-tile (tall 9) r z) = ws)
      !(wincol <(lay-tile (tall 2) r (zfrom ())))))

; --- the layout modifiers: each wraps a layout ---
(: (area p) (p 3 * p 4)
   (sumarea ps) (foldl (a \ p \ a + area p) 0 ps)
   r (rct 0 0 800 600) z3 (zfrom '(10 20 30)) z1 (zfrom '(10))
   L1 (resizable-tall 1 0.02 0.5)
   base (choice [L1 (dwindle 1.618)])
   stk (minimize (smart-borders (toggle-full (mirror base))))                    ; the config's shape
   (test
      ; mirror transposes: master moves to the top, the partition is preserved
      (: m (lay-msg (mirror L1) 'mirror z3) p <(lay-tile m r z3)
         ((<p = '(10 0 0 800 300)) && (sumarea p = 480000)))
      (lay-tile (mirror L1) r z3 = [<(lay-tile L1 r z3) (mirror L1)])
      ; Dwindle is a golden spiral: the focus takes phi/(1+phi) of the width, still a partition
      (<(lay-tile (dwindle 1.618) r z3) @ p
       (<p 3 = int (1.618 / 2.618 * 800) && sumarea p = 480000 && #p = 3))
      ; toggleLayouts Full: off = inner, on = the focus fullscreen
      (#<(lay-tile (toggle-full L1) r z3) = 3)
      (<<(lay-tile (lay-msg (toggle-full L1) 'toggle-layout z3) r z3) = '(10 0 0 800 600))
      ; smartBorders: a lone window (or a fullscreen one) gets a border-0 hint (a 6th field)
      (<(lay-tile (smart-borders L1) r z1) @ p (#<p = 6 && <p 5 = 0))
      (<(lay-tile (smart-borders L1) r z3) @ p (all (q \ #q = 5) p))
      ; minimize filters a window out of the row; the rest re-tile; restore brings it back
      (<(lay-tile (lay-msg (minimize L1) '(minimize-window 20) z3) r z3) @ p
       (#p = 2 && !(afind (q \ q 0 = 20) p)))
      (lay-msg (lay-msg (minimize L1) '(minimize-window 20) z3) 'restore z3 @ mm
       (#<(lay-tile mm r z3) = 3))
      ; windowNavigation geometry: nearest window in a direction
      (<(lay-tile L1 r z3) @ pls
       (nav-target pls 10 'right = 20 && !(nav-target pls 10 'left)
        && nav-target pls 20 'left = 10 && nav-target pls 20 'down = 30))
      ; the whole config stack composes: messages reach the base, partition holds
      (sumarea <(lay-tile stk r z3) = 480000)
      (#<(lay-tile (lay-msg stk 'next-layout z3) r z3) = 3)
      (<(lay-tile (lay-msg stk 'toggle-layout z3) r z3) @ q (#q = 1 && <q 5 = 0))))                 ; through the stack: fullscreen, borderless

; --- a layout whose head is a closure answers 'tile/'msg itself: user layouts are plain
; data, and modifiers wrap them like any builtin ---
(: (q op lay a b) (op @ 'tile (zfoc b @ f                                  ; focus in a fixed corner box; state = (lay 1)
                               [(f ? [(f . rct 0 0 100 (lay 1))] ()) lay])
                        'msg (a @ 'grow [<lay (lay 1 + 10)]))
   Q [q 50] r (rct 0 0 800 600) z3 (zfrom '(10 20 30))
   (test
      (<(lay-tile Q r z3) = '((10 0 0 100 50)))
      (<>(lay-tile Q r z3) = Q)
      (lay-msg Q 'grow z3 1 = 60)
      !(lay-msg Q 'shrink z3)                                                    ; one it doesn't reads (), so modifiers fall through
      (<(lay-tile (smart-borders Q) r z3) @ p
       (#p = 1 && #<p = 6))
      (lay-msg (smart-borders Q) 'grow z3 1 1 = 60)))                  ; a delegated message threads the closure's new state

; --- the manageHook dsl (manage.l): combinators + float actions ---
(: s0 (admit (admit (sheaf '(1 2 3)) 10) 20)                                     ; ws1 tiled (20 10); we manage 20
   c (mg-ctx 0 20 (rct 0 0 800 600) (rct 100 100 300 200))                      ; socket 0 unused: pure actions and mocks
   yes (c \ 1) no (c \ 0)
   tag (nm \ _ \ sh \ nm . sh)                                               ; mock action: marks it ran
   (test
      ; float actions move the tiled window into the floating half
      (do-full-float c s0 @ f (wsfloating? f 20 && wsrect f 20 = '(0 0 800 600) && !(any (= 20) (wstiled f))))
      (do-float c s0 @ f (wsrect f 20 = '(100 100 300 200)))
      (do-center-float c s0 @ f (wsrect f 20 = '(250 200 300 200)))             ; (800-300)/2, (600-200)/2
      (do-ignore c s0 = evict s0 20)
      ; <||> is predicate or, and it reads as one: `p <||> q`
      ((yes <||> no) c) !((no <||> no) c) ((no <||> yes) c)
      ((no <||> no <||> yes) c)                                                  ; chains right, so a run of alternatives is one rule
      ; -?> fires the action iff the predicate matches (a 1-list = matched, () = not)
      (((yes -?> tag 'a) c s0) = [('a . s0)])
      !((no -?> tag 'a) c s0)
      ; the two bind so a rule needs no inner parens: `p <||> q -?> act`
      (((no <||> yes -?> (tag 'a)) c s0) = [('a . s0)])
      ; compose-one takes the first matching rule; none -> the sheaf unchanged
      ((compose-one [(no -?> tag 'a) (yes -?> tag 'b) (yes -?> tag 'c)] c s0) = ('b . s0))
      ((compose-one [(no -?> tag 'a) (no -?> tag 'b)] c s0) = s0)
      ; compose-all threads every hook
      ((compose-all [(c \ sh \ 'x . sh) (c \ sh \ 'y . sh)] c s0) = ('y . 'x . s0))
      ; manage-for is the assembled hook, X-driven; not called here
      (lit? manage-default) (lit? (manage-for '("a") '("b") '("c")))))

; --- the Go/Swap zipper halves: focus/swap by name ---
(zmk 2 '(1) '(3) @ z3
 (test
    (zfoc (zfocto 3 z3) = 3) (zrow (zfocto 3 z3) = '(1 2 3))
    (zfocto 2 z3 = z3) (zfocto 9 z3 = z3)
    (zrow (zswapw 1 3 z3) = '(3 2 1)) (zfoc (zswapw 1 3 z3) = 2)                 ; focus keeps its window
    (zrow (zswapw 2 3 z3) = '(1 3 2)) (zfoc (zswapw 2 3 z3) = 2)                 ; even when the focus is a swap party
    (zswapw 1 3 (zswapw 1 3 z3) = z3)
    (zswapw 1 9 z3 = z3)))

; --- the keymap (keys.l): the table's shape, the union law, nextMatch ---
(: (test
      ; every binding is (lib keysym action), the action a tagged list
      (all (r \ #r = 3 && two? (kb-act r) && name? <(kb-act r)) the-keys)
      (kmodmask = shiftm | ctrlm | altm | supm)
      ; the directional generator: 4 dirs x 2 keysyms x 3 modifier rows
      (#keys-dir = 24)
      (keys-find keys-dir supm 104 = '(go left (-20 0)))
      (keys-find keys-dir (supm | shiftm) xk-up = '(swapd up (0 -20)))
      (keys-find keys-dir (supm | ctrlm) 106 = '(resize down (0 20)))
      ; the union: custom wins on a collision, stock survives elsewhere
      (#keys-custom = 43) (#keys-def = 45) (#the-keys = 74)       ; 14 stock rows shadowed
      (keys-find the-keys supm 114 = '(screen 2)) (keys-find the-keys (supm | shiftm) 119 = '(to-screen 0))
      (keys-find the-keys supm 119 = '(screen 0)) (keys-find the-keys supm 115 = '(float-toggle))   ; w/e/r free of custom
      (keys-find the-keys supm xk-ret = '(spawn ("xfce4-terminal")))
      (keys-find the-keys supm 109 = '(msg mirror))
      (keys-find the-keys (supm | shiftm) xk-ret = '(spawn ("xterm")))
      (keys-find the-keys supm 116 = '(sink))
      (keys-find the-keys supm 49 = '(view 1))
      (keys-find the-keys (supm | shiftm) 57 = '(shift 9))
      !(keys-find the-keys supm 999)
      ; nextMatch's mru pick: forward = most recent other, backward = oldest
      (nm-pick '(10 20 30) 10 '(10 20 30) 1 = 20)
      (nm-pick '(10 20 30) 10 '(10 20 30) 0 = 30)
      (nm-pick '(10 20 30) 10 '(10) 1 = 20)                                      ; never-focused windows count as oldest
      (nm-pick '(10 20) 10 '(99 20 10) 1 = 20)                                   ; other-workspace history is ignored
      !(nm-pick '(10) 10 '(10) 1)))

; --- EWMH + docks (ewmh.l): strut arithmetic + wire encodings ---
(: (test
      ; _net_wm_strut_partial's 12 values ride whole; _net_wm_strut's 4 get whole-edge spans; short = none
      (strut-parse '(0 0 30 0 0 0 0 0 0 0 400 800) = '(0 0 30 0 0 0 0 0 0 0 400 800))
      (strut-parse '(0 0 30 0) = '(0 0 30 0 0 65535 0 65535 0 65535 0 65535))
      !(strut-parse '(1 2))
      ; struts clamp the rect off each edge; a swallowed axis floors at 0
      (strut-shrink (rct 0 0 800 600) (strut-parse '(0 0 30 0)) 800 600 = '(0 30 800 570))
      (strut-shrink (rct 0 0 800 600) (strut-parse '(0 50 0 20)) 800 600 = '(0 0 750 580))
      (strut-shrink (rct 0 0 100 100) (strut-parse '(700 0 0 0)) 800 600 2 = 0)))

; the desktop's shape for pagers: names as NUL-terminated strings, one row of values per desktop
(string 0 @ nul
 (test (ewmh-names '(1 2 3) = "1" + nul + "2" + nul + "3" + nul) (ewmh-names () = "")
       (ewmh-per '(1 2 3) '(0 0) = '(0 0 0 0 0 0)) (ewmh-per '(7) '(1 2 3 4) = '(1 2 3 4)) !(ewmh-per () '(0 0))))

; a partial strut reaches only the screens its span meets: a bottom panel under the left screen
(: st (strut-parse '(0 0 0 20 0 0 0 0 0 0 0 799)) l (rct 0 0 800 600) r (rct 800 0 800 600)
   (test (strut-shrink l st 1600 600 = '(0 0 800 580)) (strut-shrink r st 1600 600 = r)
         (strut-shrink r (strut-parse '(0 0 0 20)) 1600 600 = '(800 0 800 580))))   ; a plain strut: the whole edge

(: _ (pin ewst 'struts [[77 (strut-parse '(0 0 30 0))] [88 (strut-parse '(40 0 0 0))]]) _ (pin ewst 'avoid 1)
   r1 (ewmh-rect (rct 0 0 800 600) 800 600)
   _ (ewmh-toggle ()) r2 (ewmh-rect (rct 0 0 800 600) 800 600)                   ; ToggleStruts: the full screen again
   _ (ewmh-toggle ()) _ (ewmh-untrack 88) r3 (ewmh-rect (rct 0 0 800 600) 800 600)
   (pin ewst 'struts (),
    (test (r1 = '(40 30 760 570)) (r2 = '(0 0 800 600)) (r3 = '(0 30 800 570)))))

; --- the property/window encodings, byte-exact into a jug ---
(: j (jug 0) _ (x-chprop32 j 5 6 7 '(9 10)) b (slurp j)
   (test (#b = 32) (b 0 = 18) (b 2 = 8)                                   ; opcode, len 6+2
         (b 4 = 5) (b 8 = 6) (b 12 = 7)
         (b 16 = 32) (b 20 = 2) (b 24 = 9) (b 28 = 10)))

(: j (jug 0) _ (x-chprop8 j 5 6 7 "AB") b (slurp j)
   (test (#b = 28) (b 0 = 18) (b 2 = 7)                                   ; len 6 + 1 (2 chars + pad)
         (b 16 = 8) (b 20 = 2) (b 24 = 65) (b 25 = 66) (b 26 = 0)))            ; format 8, n=2, "ab\0\0"

(: j (jug 0) _ (x-mkwin j 42 7) b (slurp j)
   (test (#b = 32) (b 0 = 1) (b 4 = 42) (b 8 = 7)
         (b 12 = 255) (b 13 = 255) (b 16 = 1) (b 22 = 2)))                     ; x=-1, w=1, class InputOnly

; --- ClientMessage field reads (win@4 type@8 data@12,16,20) ---
(('(33 32 0 0 9 0 0 0 5 0 0 0 2 0 0 0 7 0 0 0 8 0 0 0) + '(0 0 0 0 0 0 0 0)) @ pk
 (test (ewmh-cm-win pk = 9) (ewmh-cm-type pk = 5)
         (ewmh-cm-d0 pk = 2) (ewmh-cm-d1 pk = 7) (ewmh-cm-d2 pk = 8)))

; --- the config (config.l): every law reads an empty tablet, never lux-cfg's, so the
; gate means the same on a machine with its own ~/.love/etc/lux.l ---
(: c0 {}
   lay0 (foldr lux-wrap-of (choice (filter two? (map lux-lay-of (conf-roster c0 'layout '((rtall 1 0.02 0.5) (dwindle phi))))))
               (conf-roster c0 'layout-wrap '(minimize smart toggle-full mirror)))
   sm (lay0 2) tf (sm 1) mir (tf 2) ch (mir 2)               ; peel minimize/smart/toggle/mirror down to the |||
   subs (ch 2) rt <subs dw <>subs
   (test
      (salt-one c0 'border 3 = 3) (conf-tags c0 = 9) (conf-mod c0 = supm)
      (<lay0 = 'minimize) (<sm = 'smart) (<tf = 'toggle-lay)
      (<mir = 'mirror) (<ch = 'choice)
      (<rt = 'rtall) (rt 1 = 1) (rt 2 = 0.5)
      (<dw = 'dwindle)
      (dw 1 @ phi (1.61803 < phi && phi < 1.61804))                         ; fib 32 / fib 31
      (#(keys-build supm 20 9 () ()) = 74) (lit? (manage-for '("a") '("b") ()))
      (<<(conf-roster c0 'startup '(("setxkbmap"))) = "setxkbmap")))

; --- the config door (salt): every setting overrides, its absence the default. the tablet
; is built by hand: a setting's whole tail under its head, as salt-file writes it ---
(: (st l) (foldl (t \ p \ pin t <p >p) {} l)                             ; a settings roster -> the tablet salt would answer
   c1 (st '((border 5) (mod alt) (tags 4) (nudge 7)
            (layout (dwindle 2.0)) (layout-wrap smart)
            (float-class inkscape "blender") (center-class ()) (startup ())))
   lay1 (foldr lux-wrap-of (choice (filter two? (map lux-lay-of (conf-roster c1 'layout '((rtall 1 0.02 0.5))))))
               (conf-roster c1 'layout-wrap '(minimize smart toggle-full mirror)))
   km (keys-build (conf-mod c1) (salt-one c1 'nudge 20) (conf-tags c1)
                  (conf-roster c1 'bind ()) (conf-roster c1 'unbind ()))
   (test
      (salt-one c1 'border 3 = 5) (conf-tags c1 = 4) (conf-mod c1 = altm)
      (<lay1 = 'smart) (<(lay1 1) = 'choice)                                ; layout-wrap replaces the whole stack
      (#(lay1 1 2) = 1)                                         ; the config's dwindle
      (<<(lay1 1 2) = 'dwindle)
      !(conf-roster c1 'center-class ())                                         ; `(k ())` is the empty roster
      (#(conf-roster c1 'float-class '("x")) = 2)
      !(conf-roster c1 'startup '(("setxkbmap")))                                ; so a config can spawn nothing
      (#(conf-roster c1 'ignore-class '("k")) = 1)                          ; an absent roster keeps the default
      (keys-find km altm 120 = '(kill))                                          ; the whole table moved to the new mod
      !(keys-find km supm 120)
      (keys-find km altm 104 = '(go left (-7 0)))                                ; nudge feeds the directional deltas
      (keys-find km altm 52 = '(view 4)) !(keys-find km altm 53)                 ; digit rows stop at the tag count
      (two? (lux-cfg 'tags)) (two? (lux-cfg 'keymap)) (lit? (lux-cfg 'manage)) (two? (lux-cfg 'layout))))   ; the live ones built, whatever this machine's file says

; --- key specs: the surface a config writes chords in ---
(: c2 (foldl (t \ p \ pin t <p >p) {}
             '((bind ((sup Return) (spawn "alacritty" "-e" "tmux"))
                     ((sup shift F1) (view 1))
                     ((mod XF86AudioMute) (spawn "amixer" "set" "Master" "toggle"))
                     ((sup 65027) (kill))
                     ((nonsense q) (kill)))
               (unbind (sup p) (sup z) (sup bogus))))
   km (keys-build supm 20 9 (conf-roster c2 'bind ()) (conf-roster c2 'unbind ()))
   (test
      (kspec supm '(sup e) = '(64 101))                                          ; a one-char key is its ascii keysym
      (kspec supm '(sup shift Return) = '(65 65293))                             ; masks or together, names come off the table
      (kspec altm '(mod Tab) = '(8 65289))                                       ; `mod` follows the configured modifier
      (kspec supm '(F7) = '(0 65476))                                            ; no modifier is a mask of 0, not a failure
      (kspec supm '(sup ",") = '(64 44))                                         ; a one-char string is that character
      (kspec supm '(sup "1") = '(64 49))
      (kspec supm '(sup 65027) = '(64 65027))                                    ; a bare charm is the keysym
      !(kspec supm '(sup 1)) !(kspec supm '(sup 0))                              ; not below 32: `1` is the digit's trap, not its keysym
      !(kspec supm '(sup nosuchkey)) !(kspec supm '(bogus e))                    ; an unknown field kills the whole spec
      !(kspec supm 'sup+e) !(kspec supm ())                                      ; a bare name is not a spec
      (keys-find km supm xk-ret = '(spawn ("alacritty" "-e" "tmux")))            ; argv rides in flat and lands nested
      (keys-find km (supm | shiftm) 65470 = '(view 1))
      (keys-find km supm 269025042 = '(spawn ("amixer" "set" "Master" "toggle")))
      (keys-find km supm 65027 = '(kill))
      !(keys-find km supm 112) !(keys-find km supm 122)                          ; unbind cuts, and cuts last
      (keys-find km supm 120 = '(kill))                                          ; only what it names
      (#km = 75)))                                                          ; 74 stock, +3 new rows, -2 unbound

; --- ~/.Xauthority parsing (wire.l), on mock bytes ---
(: (be16 n) (string (n >> 8) + string (255 & n))                                        ; big-endian u16
   (fld t) (be16 #t + t)
   (entry num data) (be16 256 + fld "bee" + fld num + fld "MIT-MAGIC-COOKIE-1" + fld data)
   b (entry "0" "aaaabbbbccccdddd" + entry "7" "0123456789abcdef")
   (test
      (xauth-parse b "7" = '("MIT-MAGIC-COOKIE-1" "0123456789abcdef"))
      (<>(xauth-parse b "0") = "aaaabbbbccccdddd")
      !(xauth-parse b "9")
      !(xauth-parse "" "0")))

; --- a client's own window: the display number, and its requests byte-exact into a jug ---
(test ("0" = x-dispnum "") ("0" = x-dispnum ":") ("7" = x-dispnum ":7")
      ("12" = x-dispnum ":12.0"))
(: j (jug 0) _ (x-window j 9 1 640 400 131075) b (slurp j)                      ; CreateWindow: back pixel + event mask
   (test (#b = 40) (b 0 = 1) (b 2 = 10) (b 4 = 9) (b 8 = 1) (u16 b 16 = 640) (u16 b 18 = 400)
         (u32 b 28 = 2050) (u32 b 32 = 0) (u32 b 36 = 131075)))
(: j (jug 0) _ (x-title j 9 "doom") b (slurp j)                                  ; ChangeProperty WM_NAME, padded
   (test (#b = 28) (b 0 = 18) (u16 b 2 = 7) (u32 b 8 = 39) (u32 b 20 = 4) ("doom" = snip b 24 28)))
(: j (jug 0) fb (cask (2000 * 40 * 4))
   _ (x-putrows j 9 10 24 fb 2000 0 40) b (slurp j)                              ; 8000-byte rows: bands of 32, then 8
   (test (#b = 24 + 32 * 8000 + 24 + 8 * 8000)
         (b 0 = 72) (u16 b 2 = 6 + 32 * 8000 // 4) (u16 b 14 = 32) (u16 b 18 = 0)
         (b (24 + 32 * 8000) = 72) (u16 b (24 + 32 * 8000 + 14) = 8) (u16 b (24 + 32 * 8000 + 18) = 32)))

; --- a window's events off recorded X event bytes: keys by place, text by keysym ---
(: (ev c d x y st w32)                                                           ; one 32-byte event, decoded as x-next would
    (: j (jug 0)
       _ (x-w8 j c, x-w8 j d, x-w16 j 7, x-w32 j 1, x-w32 j 2, x-w32 j w32, x-w32 j 0,   ; data[0] at 12
          x-w16 j x, x-w16 j y, x-w16 j x, x-w16 j y, x-w16 j st, x-w8 j 1, x-w8 j 0)    ; w h at 20, x y at 24
       (slurp j @ b (x-decode (map b ^32))))
   km (pin (pin (tablet 4) 38 [97 65]) 21 [61 43]) dl 77
   (key c kc st) (x-events (ev c kc 0 0 st 0) km dl)
   (test (x-set1 9 = 1) (x-set1 38 = 30) (x-set1 94 = 86) (x-set1 96 = 88)              ; esc, a, the 102nd key, f12
         (x-set1 111 = 328) (x-set1 105 = 285) (x-set1 133 = 347) !(x-set1 255)          ; up, right ctrl, left meta, none
         (key 2 38 0 = [['down 30] ['text "a"]]) (key 2 38 1 = [['down 30] ['text "A"]])
         (key 2 38 2 = [['down 30] ['text "A"]]) (key 2 21 2 = [['down 13] ['text "="]])  ; caps lock shifts letters only
         (key 3 38 1 = [['up 30]]) (key 2 38 4 = [['down 30]]) (key 2 38 8 = [['down 30]]) ; a release, ctrl, alt: no text
         (key 2 111 0 = [['down 328]]) (key 2 255 0 = ())
         (x-events (ev 4 3 10 20 0 0) km dl = [['press 3 10 20]])
         (x-events (ev 5 1 65535 2 0 0) km dl = [['release 1 -1 2]])
         (x-events (ev 6 0 5 6 0 0) km dl = [['move 5 6]]) (x-events (ev 22 0 640 400 0 0) km dl = [['size 640 400]])
         (x-events (ev 33 32 0 0 0 dl) km dl = [['close]]) (x-events (ev 33 32 0 0 0 5) km dl = ())
         (x-events (ev 17 0 0 0 0 0) km dl = [['close]]) (x-events (ev 12 0 0 0 0 0) km dl = ())))

; --- more wire encodings, byte-exact into a jug ---
(: j (jug 0) _ (x-borderpix j 5 77) b (slurp j)
   (test (#b = 16) (b 0 = 2) (b 4 = 5) (b 8 = 8) (b 12 = 77)))
(: j (jug 0) _ (x-cursor j 9 41 42) b (slurp j)
   (test (#b = 76)
           (b 0 = 45) (b 2 = 5) (b 4 = 41) (b 12 = 99)                           ; OpenFont len 5, fid, 'c'
           (b 20 = 94) (b 24 = 42) (b 36 = 68)                                   ; CreateGlyphCursor, cid, glyph 68
           (b 52 = 46) (b 60 = 2) (b 68 = 0) (b 69 = 64) (b 72 = 42)))           ; CloseFont; cwa mask 0x4000, value cid

; --- minimize's targeted restore (a taskbar activate) ---
(: z3 (zfrom '(10 20 30)) r (rct 0 0 800 600)
   M (lay-msg (minimize (resizable-tall 1 0.02 0.5)) '(minimize-window 20) z3)
   (test
      (#<(lay-tile M r z3) = 2)
      (#<(lay-tile (lay-msg M '(restore-window 20) z3) r z3) = 3)
      !(lay-msg M '(restore-window 30) z3)))

; --- bsp: the wharf plan as a layout. row and plan stay in step, placements sit inside the
; rect without overlap, and the messages move the focus's split ---
(: r (rct 10 20 800 600)
   (bz row foc) (zmk foc (rev (take (posof foc row) row)) (drop (posof foc row + 1) row))
   (tile lay row foc) (lay-tile lay r (bz row foc))
   (inside p) (rx r <= p 1 && p 1 + p 3 <= rx r + rw r && ry r <= p 2 && p 2 + p 4 <= ry r + rh r)
   (apart p q) (p 1 + p 3 <= q 1 || q 1 + q 3 <= p 1 || p 2 + p 4 <= q 2 || q 2 + q 4 <= p 2)
   (sound pls) (all inside pls && all (p \ all (q \ p 0 = q 0 || apart p q) pls) pls)
   (grow lay row foc) (tile lay row foc @ [pls l2] [pls l2])
   s1 (grow (bsp 'beside 50 4) [1] 1)
   s2 (grow (s1 1) [1 2] 1)
   s3 (grow (lay-msg (s2 1) 'split-stack (bz [1 2] 2)) [1 2 3] 2)
   s4 (grow (s3 1) [1 3] 3)
   (test
      ('((1 10 20 800 600)) = <s1)
      (sound <s2) (sound <s3) (sound <s4)
      ([1 2] = sort (map (p \ p 0) <s2)) ([1 2 3] = sort (map (p \ p 0) <s3))
      ([1 3] = sort (cite 'wharf 'wharf-panes (s4 1 1)))                                   ; a gone window leaves the plan
      (<s2 0 3 + 4 + <s2 1 3 = 800)                                             ; the gap is spent between the halves
      (#(filter (p \ p 0 = 3 && p 2 > 20) <s3) = 1)                             ; split-stack: 3 under 2
      (lay-msg (s4 1) 'expand (bz [1 3] 3) @ e (e 1 1 = 55 || e 1 1 = 45))      ; expand moves the focus's split
      (lay-msg (s4 1) 'rotate (bz [1 3] 3) @ t (t 1 0 = 'stack))
      !(lay-msg (s4 1) 'nonsense (bz [1 3] 3))))

(test_fin ())                                        ; quit before claiming ok
(say err "test/law/lux: StackSet zipper + sheaf + floating + layout + modifier + manage + keymap + ewmh + config laws ok
")
