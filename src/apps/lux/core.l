; src/apps/lux/core.l -- the pure StackSet, xmonad's StackSet.hs: a focus zipper per
; workspace holding every window on it, floats included, a floating map carrying geometry
; alone, and the screens. one focus, one home tag, no second copy to drift.
; src/tools/wm2uu.l reads this file's post-opfix tree: a rewrite that changes the tree,
; even value-equal, must teach the translator first.
; a body-less top-level `:`, so the other lux files see this vocabulary once concatenated.
(:
   ; --- the app's own list utility ---
   (afind pred l) (? (atom? l) () (pred <l) <l (afind pred >l))    ; first match, else ()

   ; --- the zipper: () or (focus up down), up reversed (nearest-first) ---
   (zmk f up dn) [f up dn]
   (zfoc z) (two? z ? <z)                                     ; () if empty
   (zrow z) (two? z ? (rev <>z + (<z . <>>z)))               ; master first
   (zfrom l) (two? l ? (zmk <l () >l))
   (zrev z) (two? z ? (zmk <z <>>z <>z))
   (zfocup z) (atom? z ? ()
                 (: up <>z
                    (two? up ? (zmk <up >up (<z . <>>z))
                       (: all (rev (<z . <>>z)) (zmk <all >all ())))))
   (zfocdn z) (zrev (zfocup (zrev z)))
   (zswapup z) (atom? z ? ()
                  (: up <>z
                     (two? up ? (zmk <z >up (<up . <>>z))
                        (zmk <z (rev <>>z) ()))))                  ; at the top: rotate to the bottom
   (zswapdn z) (zrev (zswapup (zrev z)))
   (zmaster z) (atom? z ? () (zmk <z () (rev <>z + <>>z)))
   (zins w z) (two? z ? (zmk w <>z (<z . <>>z)) (zmk w () ()))  ; inserted above the focus, focused
   (znub w l) (filter (x \ x != w) l)
   (zdel w z) (atom? z ? ()                                        ; focus falls down, then up
                 (: f <z up (znub w <>z) dn (znub w <>>z)
                    (? (f != w) (zmk f up dn)
                       (two? dn) (zmk <dn up >dn)
                       (two? up) (zmk <up >up ())
                       ())))
   (zhas? w z) (any (x \ x = w) (zrow z))
   (zfromrow row f) (: (go up m) (? (atom? m) ()                   ; () if f absent
                                    (<m = f) (zmk f up >m)
                                    (go (<m . up) >m))
                       (go () row))
   (zfocto w z) (zhas? w z ? (zfromrow (zrow z) w) z)
   (zswapw a b z) (zhas? a z && zhas? b z ?                        ; focus follows its window
                     (zfromrow (map (x \ (? (x = a) b (x = b) a x)) (zrow z)) (zfoc z)) z)

   ; --- the sheaf: (cur board floating vis). board = ((tag zipper)..), every tag;
   ;     vis = ((tag rect)..), the tags on screen in screen order, cur one of them.
   ;     floating = ((window rect)..), geometry alone: a window's workspace is
   ;     whichever zipper holds it ---
   (sheaf tags) [<tags (map (t \ [t ()]) tags) () [[<tags ()]]]      ; one screen, its rect unknown until wsrescreen
   (wscur sh) <sh
   (wsboard sh) <>sh
   (wsfloat sh) <>>sh
   (wsvis sh) (sh 3)
   (wsmake cur board float vis) [cur board float vis]
   (wsknown? sh t) (any (p \ <p = t) (wsboard sh))
   (wsget sh t) (: p (assoc t (wsboard sh)) (two? p ? <>p))
   (wsset sh t z) (wsmake (wscur sh) (map (p \ <p = t ? [t z] p) (wsboard sh)) (wsfloat sh) (wsvis sh))

   ; --- screens: view/greedy/rescreen are xmonad's ---
   (wsvistags sh) (map cap (wsvis sh))
   (wsvisible? sh t) (any (p \ <p = t) (wsvis sh))
   (wshidden sh) (filter (t \ !(wsvisible? sh t)) (map cap (wsboard sh)))
   (wsrectof sh t) (assoc t (wsvis sh) @ (_ . r . _) r ())
   (wsswapvis vis a b) (map (p \ (<p = a ? [b <>p] (<p = b ? [a <>p] p))) vis)   ; b hidden: a's screen shows b
   (wsview sh t)                                                   ; a hidden tag takes the current screen, a visible one the focus
    (? (!(wsknown? sh t) || t = wscur sh) sh
       (wsmake t (wsboard sh) (wsfloat sh)
               (wsvisible? sh t ? (wsvis sh) (wsswapvis (wsvis sh) (wscur sh) t))))
   (wsgreedy sh t)                                                 ; the two tags trade screens
    (? (!(wsknown? sh t) || t = wscur sh) sh
       (wsmake t (wsboard sh) (wsfloat sh) (wsswapvis (wsvis sh) (wscur sh) t)))
   (wspair ts rs) (two? ts && two? rs ? ([<ts <rs] . wspair >ts >rs))
   (wswithin? a b) (b 0 <= a 0 && b 1 <= a 1 && a 0 + a 2 <= b 0 + b 2 && a 1 + a 3 <= b 1 + b 3)
   (wsclean rects)                                                 ; a rect inside another is no screen; the first of equals stays
    (: (go seen l) (? (atom? l) (rev seen)
                      (any (k \ wswithin? <l k) seen) (go seen >l)
                      (any (k \ wswithin? <l k && <l != k) >l) (go seen >l)
                      (go (<l . seen) >l))
       (go () rects))
   (wsrescreen sh rects)                                           ; visible tags keep their screens in order,
    (: rs (sort (wsclean rects))                                   ; hidden ones fill new screens, the rest hide;
       (atom? rs ? sh                                              ; screens go by position, leftmost first
          (: tags (take #rs (wsvistags sh + wshidden sh))
             cur (any (= (wscur sh)) tags ? (wscur sh) <tags)
             (wsmake cur (wsboard sh) (wsfloat sh) (wspair tags rs)))))
   (wsring sh) (zrow (wsget sh (wscur sh)))                        ; tiles and floats alike
   (wsfoc sh) (zfoc (wsget sh (wscur sh)))                         ; a float names itself
   (wsmap sh f) (wsset sh (wscur sh) (f (wsget sh (wscur sh))))

   ; --- floating: the alist carries geometry only, so floating and sinking never move
   ;     a window in the ring ---
   (wsunfl w fl) (filter (p \ <p != w) fl)
   (wsfloating? sh w) (any (p \ <p = w) (wsfloat sh))
   (wsrect sh w) (: p (assoc w (wsfloat sh)) (two? p ? <>p))
   (wsflof sh t) (filter (w \ wsfloating? sh w) (wsringof sh t))
   (wsflhere sh) (wsflof sh (wscur sh))
   (wsvisflof sh t) (map (w \ [w (wsrect sh w)]) (wsflof sh t))  ; as (window rect), for the painter
   (wsvisfl sh) (wsvisflof sh (wscur sh))
   (wsdofloat sh w r)                                              ; w already in the ring
    (wsknownw? sh w ? (wsrehome (wsmake (wscur sh) (wsboard sh) ([w r] . wsunfl w (wsfloat sh)) (wsvis sh)) w) sh)
   (wsrehome sh w)                                                 ; a float on screen moves to the tag its centre is on,
    (: r (wsrect sh w) home (wstagof sh w)                         ; focused; a hidden float stays home
       t (two? r ? (wsscreenat sh (r 0 + r 2 // 2) (r 1 + r 3 // 2)))
       (? (!t || t = home || !(wsvisible? sh home)) sh
          (wsfocw (shiftwin sh w t) w)))
   (wssink sh w) (wsmake (wscur sh) (wsboard sh) (wsunfl w (wsfloat sh)) (wsvis sh))

   ; --- the tiled half: the zipper with floats filtered out (W.filter) ---
   (wstilezof sh t) (foldl (z \ w \ zdel w z) (wsget sh t) (wsflof sh t))
   (wstilez sh) (wstilezof sh (wscur sh))
   (wsrow sh) (zrow (wstilez sh))
   (wsztile sh zop)                                                ; floats keep their slots
    (: f (wsfoc sh)
       (!f || wsfloating? sh f ? sh
          (: z (zfromrow (wsrow sh) f)
             (!z ? sh
                (: ts (zrow (zop z)) row (wsring sh)
                   (fill m r) (? (atom? m) ()
                                 (wsfloating? sh <m) (<m . fill >m r)
                                 (<r . fill >m >r))
                   (wsmap sh (zz \ zfromrow (fill row ts) f)))))))
   (wsmaster sh) (wsztile sh zmaster)
   (wsswapup sh) (wsztile sh zswapup)
   (wsswapdn sh) (wsztile sh zswapdn)

   ; --- per screen ---
   (wsringof sh t) (zrow (wsget sh t))
   (wsonscreen sh) (foldl (a \ t \ a + wsringof sh t) () (wsvistags sh))
   (wsscreenof sh w) (wsrectof sh (wstagof sh w))
   (wsscreenat sh x y) (: p (afind (p \ (: r <>p (two? r && r 0 <= x < r 0 + r 2 && r 1 <= y < r 1 + r 3))) (wsvis sh))
                          (two? p ? <p))                            ; the tag under (x y), or ()
   (wsfocw sh w) (: t (wstagof sh w)                                 ; its screen becomes current
                   (t && wsvisible? sh t ? (wsmap (wsview sh t) (zfocto w)) sh))

   ; --- the whole sheaf ---
   (wsallw sh) (foldl (a \ p \ a + zrow <>p) () (wsboard sh))
   (wstiled sh) (filter (w \ !(wsfloating? sh w)) (wsallw sh))
   (wsfloatw sh) (filter (w \ wsfloating? sh w) (wsallw sh))
   (wswins sh) (wstiled sh + wsstack (wsfloatw sh) (wsfoc sh) (w \ ()))   ; the stacking order a pager reads, bottom to top
   (wsstack fl foc par)                                            ; floats bottom to top: the ring's top-first order
    (: (up w) (par w @ p (p != w && any (= p) fl ? p))             ; reversed, the focus and its owners last, a transient
       (chain w n) (w && 0 < n ? (w . chain (up w) (n - 1)))         ; just above its owner. par: window -> owner | ()
       ch (chain (any (= foc) fl ? foc) #fl)
       o (filter (w \ !(any (= w) ch)) (rev fl) + filter (w \ any (= w) ch) (rev fl))
       (tree w n) (0 < n ? (w . foldl (a \ c \ a + tree c (n - 1)) () (filter (c \ up c = w) o)))
       t (foldl (a \ r \ a + tree r #fl) () (filter (w \ !(up w)) o))
       (t + filter (w \ !(any (= w) t)) o))                         ; an owner cycle has no root: its windows go last
   (wsknownw? sh w) (any (x \ x = w) (wsallw sh))
   (wsdelw sh w) (map (p \ [<p (zdel w <>p)]) (wsboard sh))
   (wstagof sh w) (: r (filter (p \ zhas? w <>p) (wsboard sh))
                     (two? r ? <<r))
   (admit sh w) (wsknownw? sh w ? sh (wsmap sh (zins w)))
   (evict sh w) (wsmake (wscur sh) (wsdelw sh w) (wsunfl w (wsfloat sh)) (wsvis sh))
   (shiftwin sh w t) (? !(wsknown? sh t && wsknownw? sh w && t != wstagof sh w) sh
                        (: d (wsmake (wscur sh) (wsdelw sh w) (wsfloat sh) (wsvis sh))   ; a float emigrates with its rect
                           (wsset d t (zins w (wsget d t)))))                 ; and arrives focused
   (shiftto sh t) (shiftwin sh (wsfoc sh) t)                       ; we stay
   (wssane? sh) (wsknown? sh (wscur sh) && znodup? (wsallw sh)     ; the invariant: no window twice,
                  && all (p \ wsknownw? sh <p) (wsfloat sh)        ; no rect without a window,
                  && wsvisible? sh (wscur sh) && znodup? (wsvistags sh)   ; the current tag on a screen, no tag on two,
                  && all (t \ wsknown? sh t) (wsvistags sh))       ; and every screen showing a real tag
   (znodup? l) (? (atom? l) 1 (any (x \ x = <l) >l) 0 (znodup? >l)))
