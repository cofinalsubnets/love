; apps/lux/core.l -- the pure StackSet: the window model, no X and no sockets. This is
; xmonad's StackSet.hs: a focus zipper per workspace holding every window on it,
; floats included, a floating map (window -> rect) carrying geometry alone, and the
; screens -- which tags are on view, each with its rect. One focus, one home tag,
; no second copy to drift. Pure -- so it
; rides the corpus on every target (test/law/lux.l asserts the invariants), and the
; driver (apps/lux/lux.l) + the X layers build on it.
;
; tools/wm2uu.l reads this file as data and keys on the post-opfix tree --
; cap/cup chains (the glued accessors factor to them), ></+/!=, and the literal
; shape (cap (cup (cup z))). a rewrite that changes the tree, even value-equal,
; must teach the translator first or test/host/overlay.l's leg 6 stops certifying.
;
; a body-less top-level `:` -- every binding leaks to the global scope, so the
; other apps/lux/ files see this vocabulary once concatenated. names shadow no
; nif; the wm vocabulary is `z*` (the zipper) and `ws*`/admit/evict/shiftto/
; shiftwin (the sheaf).
(:
   ; --- the app's own list utility ---
   (afind pred l) (? (atom? l) () (pred <l) <l (afind pred >l))    ; first element satisfying pred, else ()

   ; --- the zipper: a workspace's tiled stack. () or (focus up down), up reversed
   ;     (nearest-first), so focus motion is O(1) at either end. ---
   (zmk f up dn) [f up dn]
   (zfoc z) (two? z ? <z)                                     ; the focused window (() if empty)
   (zrow z) (two? z ? (rev <>z + (<z . <>>z)))               ; the stack as an ordered row, master first
   (zfrom l) (two? l ? (zmk <l () >l))                        ; a row -> a zipper, head focused
   (zrev z) (two? z ? (zmk <z <>>z <>z))                      ; mirror: up <-> down
   (zfocup z) (? !(two? z) ()                                      ; focus up, wrapping to the bottom
                 (: up <>z
                    (? (two? up) (zmk <up >up (<z . <>>z))
                       (: all (rev (<z . <>>z)) (zmk <all >all ())))))
   (zfocdn z) (zrev (zfocup (zrev z)))                             ; focus down = mirrored focus up
   (zswapup z) (? !(two? z) ()                                     ; swap the focused window upward
                  (: up <>z
                     (? (two? up) (zmk <z >up (<up . <>>z))
                        (zmk <z (rev <>>z) ()))))                  ; at the top: rotate to the bottom
   (zswapdn z) (zrev (zswapup (zrev z)))
   (zmaster z) (!(two? z) ? () (zmk <z () (rev <>z + <>>z)))       ; focused becomes master
   (zins w z) (two? z ? (zmk w <>z (<z . <>>z)) (zmk w () ()))  ; insert above the focus, focused
   (znub w l) (filter (x \ x != w) l)
   (zdel w z) (? !(two? z) ()                                      ; delete w; focus falls down, then up
                 (: f <z up (znub w <>z) dn (znub w <>>z)
                    (? (f != w) (zmk f up dn)
                       (two? dn) (zmk <dn up >dn)
                       (two? up) (zmk <up >up ())
                       ())))
   (zhas? w z) (any (x \ x = w) (zrow z))
   (zfromrow row f) (: (go up m) (? (atom? m) ()                   ; a row -> a zipper focused at f (() if absent)
                                    (<m = f) (zmk f up >m)
                                    (go (<m . up) >m))
                       (go () row))
   (zfocto w z) (zhas? w z ? (zfromrow (zrow z) w) z)            ; focus the named window (Go dir's StackSet half)
   (zswapw a b z) (? (zhas? a z && zhas? b z)                      ; exchange a and b in place; focus follows its window
                     (zfromrow (map (x \ (? (x = a) b (x = b) a x)) (zrow z)) (zfoc z)) z)

   ; --- the sheaf: (cur board floating vis). board = ((tag zipper)..), every tag;
   ;     vis = ((tag rect)..), the tags on screen in screen order (xmonad's current
   ;     + visible), cur one of them. a zipper holds EVERY window on its workspace,
   ;     floats included, in ring order; floating = an alist ((window rect)..),
   ;     geometry alone. a window's workspace is structural -- whichever zipper
   ;     holds it -- so there is one focus and one home tag, never a second copy
   ;     to drift. ---
   (sheaf tags) [<tags (map (t \ [t ()]) tags) () [[<tags ()]]]      ; one screen, its rect unknown until wsrescreen
   (wscur sh) <sh
   (wsboard sh) <>sh
   (wsfloat sh) <>>sh
   (wsvis sh) (sh 3)
   (wsmake cur board float vis) [cur board float vis]
   (wsknown? sh t) (any (p \ <p = t) (wsboard sh))
   (wsget sh t) (: p (assoc t (wsboard sh)) (two? p ? <>p))   ; the tag's zipper
   (wsset sh t z) (wsmake (wscur sh) (map (p \ (<p = t ? [t z] p)) (wsboard sh)) (wsfloat sh) (wsvis sh))

   ; --- screens: a tag is visible when a screen shows it, hidden otherwise.
   ;     view/greedy are xmonad's view/greedyView; rescreen is its rescreen. ---
   (wsvistags sh) (map cap (wsvis sh))
   (wsvisible? sh t) (any (p \ <p = t) (wsvis sh))
   (wshidden sh) (filter (t \ !(wsvisible? sh t)) (map cap (wsboard sh)))   ; in board order
   (wsrectof sh t) (assoc t (wsvis sh) @ (_ . r . _) r ())        ; the rect of the screen showing t, or ()
   (wsswapvis vis a b) (map (p \ (<p = a ? [b <>p] (<p = b ? [a <>p] p))) vis)   ; a and b trade screens (b hidden: a's screen shows b)
   (wsview sh t)                                                   ; a hidden tag takes the current screen; a visible one takes the focus
    (? (!(wsknown? sh t) || t = wscur sh) sh
       (wsmake t (wsboard sh) (wsfloat sh)
               (wsvisible? sh t ? (wsvis sh) (wsswapvis (wsvis sh) (wscur sh) t))))
   (wsgreedy sh t)                                                 ; a visible tag comes to the current screen: the two tags trade
    (? (!(wsknown? sh t) || t = wscur sh) sh
       (wsmake t (wsboard sh) (wsfloat sh) (wsswapvis (wsvis sh) (wscur sh) t)))
   (wspair ts rs) (two? ts && two? rs ? ([<ts <rs] . wspair >ts >rs))
   (wswithin? a b) (b 0 <= a 0 && b 1 <= a 1 && a 0 + a 2 <= b 0 + b 2 && a 1 + a 3 <= b 1 + b 3)   ; rect a inside rect b
   (wsclean rects)                                                 ; a rect inside another (a clone, a nested output) is no screen: the first of equals stays
    (: (go seen l) (? (atom? l) (rev seen)
                      (any (k \ wswithin? <l k) seen) (go seen >l)                   ; inside one already kept
                      (any (k \ wswithin? <l k && <l != k) >l) (go seen >l)          ; inside a larger one still to come
                      (go (<l . seen) >l))
       (go () rects))
   (wsrescreen sh rects)                                           ; the screens changed: visible tags keep their screens in order,
    (: rs (sort (wsclean rects))                                   ; hidden ones fill new screens, tags past the last screen hide;
       (? (atom? rs) sh                                            ; screens go by position (x, then y): the leftmost is screen 0
          (: tags (take #rs (wsvistags sh + wshidden sh))
             cur (any (= (wscur sh)) tags ? (wscur sh) <tags)
             (wsmake cur (wsboard sh) (wsfloat sh) (wspair tags rs)))))
   (wsring sh) (zrow (wsget sh (wscur sh)))                        ; the focus ring: every window here, tiles and floats alike
   (wsfoc sh) (zfoc (wsget sh (wscur sh)))                         ; the focused window -- a float names itself
   (wsmap sh f) (wsset sh (wscur sh) (f (wsget sh (wscur sh))))    ; reshape the current zipper

   ; --- floating (xmonad's W.float / W.sink): the alist carries geometry only,
   ;     so lifting a window never moves it in the ring and sinking it never
   ;     moves it back. ---
   (wsunfl w fl) (filter (p \ <p != w) fl)                       ; drop w from the floating alist
   (wsfloating? sh w) (any (p \ <p = w) (wsfloat sh))            ; w is floating?
   (wsrect sh w) (: p (assoc w (wsfloat sh)) (two? p ? <>p))  ; w's float rect, or ()
   (wsflof sh t) (filter (w \ wsfloating? sh w) (wsringof sh t))   ; a tag's floats, ring order
   (wsflhere sh) (wsflof sh (wscur sh))                           ; the floats on the current view
   (wsvisflof sh t) (map (w \ [w (wsrect sh w)]) (wsflof sh t))  ; ...as (window rect), what the painter wants
   (wsvisfl sh) (wsvisflof sh (wscur sh))
   (wsdofloat sh w r)                                              ; float: pin a rect on a window already in the ring, then home it
    (wsknownw? sh w ? (wsrehome (wsmake (wscur sh) (wsboard sh) ([w r] . wsunfl w (wsfloat sh)) (wsvis sh)) w) sh)
   (wsrehome sh w)                                                 ; a float on screen belongs to the screen its centre is on: it moves to
    (: r (wsrect sh w) home (wstagof sh w)                         ; that tag, focused, its screen current; a hidden float stays home
       t (two? r ? (wsscreenat sh (r 0 + r 2 // 2) (r 1 + r 3 // 2)))
       (? (!t || t = home || !(wsvisible? sh home)) sh
          (wsfocw (shiftwin sh w t) w)))
   (wssink sh w) (wsmake (wscur sh) (wsboard sh) (wsunfl w (wsfloat sh)) (wsvis sh))   ; sink: drop the rect, the window has not moved

   ; --- the tiled half, derived. the layout sees a zipper with the floats
   ;     filtered out (W.filter: a deleted focus falls down, then up). ---
   (wstilezof sh t) (foldl (\ z w (zdel w z)) (wsget sh t) (wsflof sh t))   ; a tag's tiled zipper
   (wstilez sh) (wstilezof sh (wscur sh))
   (wsrow sh) (zrow (wstilez sh))                                  ; the current tiled row, ordered, master first
   (wsztile sh zop)                                                ; run a zipper op on the TILED subsequence; floats keep their slots
    (: f (wsfoc sh)
       (? (!f || wsfloating? sh f) sh
          (: z (zfromrow (wsrow sh) f)
             (? !z sh
                (: ts (zrow (zop z)) row (wsring sh)
                   (fill m r) (? (atom? m) ()
                                 (wsfloating? sh <m) (<m . fill >m r)
                                 (<r . fill >m >r))
                   (wsmap sh (zz \ zfromrow (fill row ts) f)))))))
   (wsmaster sh) (wsztile sh zmaster)                              ; the focused tile fronts the tiled row
   (wsswapup sh) (wsztile sh zswapup)
   (wsswapdn sh) (wsztile sh zswapdn)

   ; --- per screen: what each screen paints, and focus across screens ---
   (wsringof sh t) (zrow (wsget sh t))                              ; a tag's ring
   (wsonscreen sh) (foldl (\ a t (a + wsringof sh t)) () (wsvistags sh))   ; every window some screen shows
   (wsscreenof sh w) (wsrectof sh (wstagof sh w))                   ; the rect of the screen showing w, or ()
   (wsscreenat sh x y) (: p (afind (p \ (: r <>p (two? r && r 0 <= x < r 0 + r 2 && r 1 <= y < r 1 + r 3))) (wsvis sh))
                          (two? p ? <p))                            ; the tag on the screen under (x y), or ()
   (wsfocw sh w) (: t (wstagof sh w)                                 ; focus w wherever it is on screen: its screen becomes current
                   (t && wsvisible? sh t ? (wsmap (wsview sh t) (zfocto w)) sh))

   ; --- managing windows across the whole sheaf ---
   (wsallw sh) (foldl (\ a p (a + zrow <>p)) () (wsboard sh))      ; every managed window, all workspaces
   (wstiled sh) (filter (w \ !(wsfloating? sh w)) (wsallw sh))     ; every tiled window
   (wsfloatw sh) (filter (w \ wsfloating? sh w) (wsallw sh))       ; every floating window
   (wswins sh) (wstiled sh + wsfloatw sh)                          ; tiles then floats: the stacking order a pager reads, bottom to top
   (wsknownw? sh w) (any (x \ x = w) (wsallw sh))
   (wsdelw sh w) (map (p \ [<p (zdel w <>p)]) (wsboard sh))        ; drop w from every workspace's zipper
   (wstagof sh w) (: r (filter (p \ zhas? w <>p) (wsboard sh))     ; the tag holding w, or ()
                     (two? r ? <<r))
   (admit sh w) (wsknownw? sh w ? sh (wsmap sh (zins w)))        ; manage w into the current ws (a no-op if already managed)
   (evict sh w) (wsmake (wscur sh) (wsdelw sh w) (wsunfl w (wsfloat sh)) (wsvis sh))   ; unmanage w everywhere
   (shiftwin sh w t) (? !(wsknown? sh t && wsknownw? sh w && (t != wstagof sh w)) sh
                        (: d (wsmake (wscur sh) (wsdelw sh w) (wsfloat sh) (wsvis sh))   ; one path: a float emigrates with its rect
                           (wsset d t (zins w (wsget d t)))))                 ; and arrives focused on t
   (shiftto sh t) (shiftwin sh (wsfoc sh) t)                       ; the focused window emigrates to tag t; we stay
   (wssane? sh) (wsknown? sh (wscur sh) && znodup? (wsallw sh)     ; the StackSet invariant: no window twice,
                  && all (p \ wsknownw? sh <p) (wsfloat sh)        ; no rect without a window,
                  && wsvisible? sh (wscur sh) && znodup? (wsvistags sh)   ; the current tag on a screen, no tag on two,
                  && all (t \ wsknown? sh t) (wsvistags sh))       ; and every screen showing a real tag
   (znodup? l) (? (atom? l) 1 (any (x \ x = <l) >l) 0 (znodup? >l)))
